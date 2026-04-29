import CoreLocation
import Foundation

actor TrailSearchService {
    static let shared = TrailSearchService()

    func geocode(_ place: String) async throws -> (center: CLLocationCoordinate2D, bbox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double))? {
        // Try multiple query variants; pick the result with the largest bounding box (parks >> cities).
        let variants = [place, "\(place) national park", "\(place) wilderness", "\(place) state park"]
        var candidates: [[String: Any]] = []
        for variant in variants {
            guard let encoded = variant.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { continue }
            var req = URLRequest(url: URL(string: "https://nominatim.openstreetmap.org/search?q=\(encoded)&format=json&limit=3")!)
            req.setValue("Sapling/1.0 (dev.damsac.sapling)", forHTTPHeaderField: "User-Agent")
            guard let (data, _) = try? await URLSession.shared.data(for: req),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { continue }
            candidates.append(contentsOf: array)
        }
        guard !candidates.isEmpty else { return nil }

        func bboxArea(_ r: [String: Any]) -> Double {
            guard let bb = r["boundingbox"] as? [String], bb.count == 4,
                  let s = Double(bb[0]), let n = Double(bb[1]),
                  let w = Double(bb[2]), let e = Double(bb[3]) else { return 0 }
            return (n - s) * (e - w)
        }

        let best = candidates.max(by: { bboxArea($0) < bboxArea($1) })!

        guard let latStr = best["lat"] as? String,
              let lonStr = best["lon"] as? String,
              let lat = Double(latStr),
              let lon = Double(lonStr),
              let bb = best["boundingbox"] as? [String],
              bb.count == 4,
              let minLat = Double(bb[0]),
              let maxLat = Double(bb[1]),
              let minLon = Double(bb[2]),
              let maxLon = Double(bb[3])
        else { return nil }
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        return (center: center, bbox: (minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon))
    }

    func fetchTrails(bbox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)) async throws -> [TrailResult] {
        let q = "[out:json][timeout:25]; relation[\"route\"=\"hiking\"][\"name\"](\(bbox.minLat),\(bbox.minLon),\(bbox.maxLat),\(bbox.maxLon)); out geom;"
        return try await runOverpassQuery(q, limit: 30)
    }

    func searchByTrailName(_ query: String) async throws -> [TrailResult] {
        let escaped = query.replacingOccurrences(of: "\"", with: "\\\"")
        let q = "[out:json][timeout:30]; relation[\"route\"=\"hiking\"][\"name\"~\"\(escaped)\",i](24,-168,72,-52); out geom 15;"
        return try await runOverpassQuery(q, limit: 15)
    }

    private func runOverpassQuery(_ query: String, limit: Int) async throws -> [TrailResult] {
        guard let bodyData = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")".data(using: .utf8) else {
            return []
        }
        var request = URLRequest(url: URL(string: "https://overpass-api.de/api/interpreter")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 35
        let (data, _) = try await URLSession.shared.data(for: request)
        return Array(parseTrailElements(data).prefix(limit))
    }

    private func parseTrailElements(_ data: Data) -> [TrailResult] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = json["elements"] as? [[String: Any]]
        else { return [] }

        var results: [TrailResult] = []

        for element in elements {
            guard let tags = element["tags"] as? [String: Any],
                  let name = tags["name"] as? String,
                  !name.isEmpty
            else { continue }

            let sacScale = tags["sac_scale"] as? String
            let network = tags["network"] as? String
            let description = tags["description"] as? String

            var distanceM: Double = 0
            if let distRaw = tags["distance"] as? String {
                let trimmed = distRaw.trimmingCharacters(in: .whitespaces)
                if trimmed.hasSuffix("km"), let val = Double(trimmed.dropLast(2).trimmingCharacters(in: .whitespaces)) {
                    distanceM = val * 1000
                } else if let val = Double(trimmed) {
                    distanceM = val * 1000
                }
            }

            var coordinates: [CLLocationCoordinate2D] = []
            if let members = element["members"] as? [[String: Any]] {
                for member in members {
                    guard (member["type"] as? String) == "way",
                          let geometry = member["geometry"] as? [[String: Any]]
                    else { continue }
                    for point in geometry {
                        if let lat = point["lat"] as? Double, let lon = point["lon"] as? Double {
                            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        }
                    }
                }
            }

            guard coordinates.count >= 2 else { continue }

            if distanceM == 0 { distanceM = haversineDistance(coordinates: coordinates) }

            let id = element["id"].flatMap { val -> String? in
                if let i = val as? Int { return "relation/\(i)" }
                if let d = val as? Double { return "relation/\(Int(d))" }
                return nil
            } ?? "relation/unknown"

            results.append(TrailResult(
                id: id, name: name, distanceM: distanceM, coordinates: coordinates,
                description: description, sacScale: sacScale, network: network
            ))
        }

        return results.sorted { $0.name < $1.name }
    }

    func fetchElevation(for trail: TrailResult) async throws -> [Double] {
        let coords = trail.coordinates
        let total = coords.count
        let sampleCount = min(100, total)
        var sampled: [CLLocationCoordinate2D] = []
        if sampleCount == total {
            sampled = coords
        } else {
            for i in 0..<sampleCount {
                let index = Int(Double(i) / Double(sampleCount - 1) * Double(total - 1))
                sampled.append(coords[index])
            }
        }
        let locations = sampled.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
        guard let encoded = locations.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        let url = URL(string: "https://api.opentopodata.org/v1/srtm30m?locations=\(encoded)")!
        let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resultsArray = json["results"] as? [[String: Any]]
        else { return [] }
        return resultsArray.map { ($0["elevation"] as? Double) ?? 0.0 }
    }

    func search(query: String) async throws -> [TrailResult] {
        async let namedTask = searchByTrailName(query)
        async let geoTask = geocodeAndFetch(query)
        let named = (try? await namedTask) ?? []
        let area  = (try? await geoTask)  ?? []
        var seen = Set<String>()
        var merged: [TrailResult] = []
        for trail in named + area where seen.insert(trail.id).inserted {
            merged.append(trail)
        }
        return Array(merged.prefix(30))
    }

    private func geocodeAndFetch(_ query: String) async throws -> [TrailResult] {
        guard let (_, bbox) = try await geocode(query) else { return [] }
        return try await fetchTrails(bbox: bbox)
    }

    func nearbyTrails(center: CLLocationCoordinate2D, radiusKm: Double = 40) async throws -> [TrailResult] {
        let latDelta = radiusKm / 111.0
        let lonDelta = radiusKm / (111.0 * cos(center.latitude * .pi / 180))
        let bbox = (
            minLat: center.latitude - latDelta,
            minLon: center.longitude - lonDelta,
            maxLat: center.latitude + latDelta,
            maxLon: center.longitude + lonDelta
        )
        return try await fetchTrails(bbox: bbox)
    }
}

private func haversineDistance(coordinates: [CLLocationCoordinate2D]) -> Double {
    let R = 6371000.0
    var total = 0.0
    for i in 0..<(coordinates.count - 1) {
        let c1 = coordinates[i]
        let c2 = coordinates[i + 1]
        let lat1 = c1.latitude * .pi / 180
        let lat2 = c2.latitude * .pi / 180
        let dLat = (c2.latitude - c1.latitude) * .pi / 180
        let dLon = (c2.longitude - c1.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        total += R * c
    }
    return total
}
