import CoreLocation
import Foundation

actor TrailSearchService {
    static let shared = TrailSearchService()

    func geocode(_ place: String) async throws -> (center: CLLocationCoordinate2D, bbox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double))? {
        let lower = place.lowercased()
        let hasSpatialKeyword = lower.contains("county") || lower.contains("park")
            || lower.contains("trail") || lower.contains("wilderness")
            || lower.contains("mountain") || lower.contains("lake")
            || lower.contains("forest") || lower.contains("national")

        func fetchNominatim(_ q: String) async -> [[String: Any]] {
            guard let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
            var req = URLRequest(url: URL(string: "https://nominatim.openstreetmap.org/search?q=\(encoded)&format=json&limit=5&countrycodes=us")!)
            req.setValue("Sapling/1.0 (dev.damsac.sapling)", forHTTPHeaderField: "User-Agent")
            guard let (data, _) = try? await URLSession.shared.data(for: req),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { return [] }
            return array
        }

        var candidates: [[String: Any]]
        if hasSpatialKeyword {
            candidates = await fetchNominatim(place)
        } else {
            // Fire multiple spatial variants in parallel — catches parks, counties, forests
            async let r1 = fetchNominatim(place)
            async let r2 = fetchNominatim("\(place) State Park")
            async let r3 = fetchNominatim("\(place) County")
            async let r4 = fetchNominatim("\(place) National Park")
            candidates = await r1 + r2 + r3 + r4
        }
        guard !candidates.isEmpty else { return nil }

        func bboxArea(_ r: [String: Any]) -> Double {
            guard let bb = r["boundingbox"] as? [String], bb.count == 4,
                  let s = Double(bb[0]), let n = Double(bb[1]),
                  let w = Double(bb[2]), let e = Double(bb[3]) else { return 0 }
            return (n - s) * (e - w)
        }

        // Prefer results whose name matches the original query words, then break ties by bbox size.
        // This prevents "Big Basin County" (→ Santa Cruz County) from beating "Big Basin State Park".
        let queryWords = place.lowercased().split(separator: " ").map(String.init)
        func nameScore(_ r: [String: Any]) -> Int {
            let displayName = ((r["display_name"] as? String) ?? "").lowercased()
            return queryWords.filter { displayName.contains($0) }.count
        }
        let best = candidates.max {
            let sa = nameScore($0), sb = nameScore($1)
            if sa != sb { return sa < sb }
            return bboxArea($0) < bboxArea($1)
        }!

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

        // Ensure a minimum ~15 km radius so a point geocode still finds nearby trails
        let minDelta = 0.14
        return (
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            bbox: (
                minLat: min(minLat, lat - minDelta),
                minLon: min(minLon, lon - minDelta),
                maxLat: max(maxLat, lat + minDelta),
                maxLon: max(maxLon, lon + minDelta)
            )
        )
    }

    func fetchTrails(bbox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)) async throws -> [TrailResult] {
        let b = "\(bbox.minLat),\(bbox.minLon),\(bbox.maxLat),\(bbox.maxLon)"
        let q = """
        [out:json][timeout:30];
        (
          relation["route"="hiking"]["name"](\(b));
          relation["route"="foot"]["name"](\(b));
          relation["route"="mountain_hiking"]["name"](\(b));
          relation["route"="hiking_route"]["name"](\(b));
          relation["type"="route"]["route"~"hiking|foot|walking|trail"]["name"](\(b));
          way["highway"~"path|footway|track"]["name"](\(b));
        );
        out geom;
        """
        return try await runOverpassQuery(q, limit: 120)
    }

    func searchByTrailName(_ query: String) async throws -> [TrailResult] {
        let escaped = query.replacingOccurrences(of: "\"", with: "\\\"")
        // Relations only for US-wide name search — ways are too numerous to regex-scan globally
        let b = "18,-180,72,-65"
        let q = """
        [out:json][timeout:15];
        (
          relation["route"="hiking"]["name"~"\(escaped)",i](\(b));
          relation["route"="foot"]["name"~"\(escaped)",i](\(b));
        );
        out geom 20;
        """
        return try await runOverpassQuery(q, limit: 20)
    }

    private func runOverpassQuery(_ query: String, limit: Int) async throws -> [TrailResult] {
        guard let bodyData = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")".data(using: .utf8) else {
            return []
        }
        var request = URLRequest(url: URL(string: "https://overpass-api.de/api/interpreter")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 45
        let (data, _) = try await URLSession.shared.data(for: request)
        return Array(parseTrailElements(data).prefix(limit))
    }

    private func parseTrailElements(_ data: Data) -> [TrailResult] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = json["elements"] as? [[String: Any]]
        else { return [] }

        struct WayAcc {
            var id: String
            var segments: [[CLLocationCoordinate2D]]
            var distanceM: Double
            var sacScale: String?
            var network: String?
            var description: String?
        }

        var wayAccByName: [String: WayAcc] = [:]
        var wayOrder: [String] = []
        var results: [TrailResult] = []
        var seenByName: [String: Int] = [:]

        for element in elements {
            guard let tags = element["tags"] as? [String: Any],
                  let name = tags["name"] as? String,
                  !name.isEmpty
            else { continue }

            let type = element["type"] as? String ?? "relation"
            let sacScale = tags["sac_scale"] as? String
            let network = tags["network"] as? String
            let description = tags["description"] as? String

            var taggedDistM: Double = 0
            if let distRaw = tags["distance"] as? String {
                let t = distRaw.trimmingCharacters(in: .whitespaces)
                if t.hasSuffix("km"), let v = Double(t.dropLast(2).trimmingCharacters(in: .whitespaces)) {
                    taggedDistM = v * 1000
                } else if let v = Double(t) {
                    taggedDistM = v * 1000
                }
            }

            if type == "way" {
                var seg: [CLLocationCoordinate2D] = []
                if let geometry = element["geometry"] as? [[String: Any]] {
                    for pt in geometry {
                        if let lat = pt["lat"] as? Double, let lon = pt["lon"] as? Double {
                            seg.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        }
                    }
                }
                guard seg.count >= 2 else { continue }

                let segDist = taggedDistM > 0 ? taggedDistM : haversineDistance(coordinates: seg)
                let elemId = element["id"].flatMap { v -> String? in
                    if let i = v as? Int { return "way/\(i)" }
                    if let d = v as? Double { return "way/\(Int(d))" }
                    return nil
                } ?? "way/unknown"

                if wayAccByName[name] == nil {
                    wayOrder.append(name)
                    wayAccByName[name] = WayAcc(
                        id: elemId, segments: [seg], distanceM: segDist,
                        sacScale: sacScale, network: network, description: description
                    )
                } else {
                    wayAccByName[name]!.segments.append(seg)
                    wayAccByName[name]!.distanceM += segDist
                    wayAccByName[name]!.sacScale = wayAccByName[name]!.sacScale ?? sacScale
                }

            } else {
                // Collect member way segments, then order them geographically
                var segments: [[CLLocationCoordinate2D]] = []
                if let members = element["members"] as? [[String: Any]] {
                    for member in members {
                        guard (member["type"] as? String) == "way",
                              let geometry = member["geometry"] as? [[String: Any]]
                        else { continue }
                        var seg: [CLLocationCoordinate2D] = []
                        for pt in geometry {
                            if let lat = pt["lat"] as? Double, let lon = pt["lon"] as? Double {
                                seg.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                            }
                        }
                        if seg.count >= 2 { segments.append(seg) }
                    }
                }
                guard !segments.isEmpty else { continue }

                let coords = joinSegments(segments)
                guard coords.count >= 2 else { continue }

                let distM = taggedDistM > 0 ? taggedDistM : haversineDistance(coordinates: coords)
                guard distM >= 200, distM <= 300_000 else { continue }

                let id = element["id"].flatMap { v -> String? in
                    if let i = v as? Int { return "relation/\(i)" }
                    if let d = v as? Double { return "relation/\(Int(d))" }
                    return nil
                } ?? "relation/unknown"

                let trail = TrailResult(
                    id: id, name: name, distanceM: distM, coordinates: coords,
                    description: description, sacScale: sacScale, network: network
                )
                if let idx = seenByName[name] {
                    results[idx] = trail
                } else {
                    seenByName[name] = results.count
                    results.append(trail)
                }
            }
        }

        // Emit stitched ways (ordered) where no relation covers the same name.
        // Require 1.5 km total so lone short fragments are dropped.
        for name in wayOrder {
            guard seenByName[name] == nil, let acc = wayAccByName[name] else { continue }
            guard acc.distanceM >= 1500, acc.distanceM <= 300_000 else { continue }

            let coords = joinSegments(acc.segments)
            guard coords.count >= 2 else { continue }

            let trail = TrailResult(
                id: acc.id, name: name, distanceM: acc.distanceM, coordinates: coords,
                description: acc.description, sacScale: acc.sacScale, network: acc.network
            )
            seenByName[name] = results.count
            results.append(trail)
        }

        return results.sorted { $0.distanceM < $1.distanceM }
    }

    // Greedy nearest-neighbour join: orders segments so each connects to the next,
    // reversing individual segments when the tail matches better than the head.
    private func joinSegments(_ segs: [[CLLocationCoordinate2D]]) -> [CLLocationCoordinate2D] {
        guard !segs.isEmpty else { return [] }
        var remaining = segs
        var ordered = [remaining.removeFirst()]
        while !remaining.isEmpty {
            let tail = ordered.last!.last!
            var bestIdx = 0, bestDist = Double.infinity, bestFlip = false
            for (i, s) in remaining.enumerated() {
                let df = sqDeg(tail, s.first!)
                let dl = sqDeg(tail, s.last!)
                if df < bestDist { bestDist = df; bestIdx = i; bestFlip = false }
                if dl < bestDist { bestDist = dl; bestIdx = i; bestFlip = true }
            }
            let next = remaining.remove(at: bestIdx)
            ordered.append(bestFlip ? next.reversed() : next)
        }
        return ordered.flatMap { $0 }
    }

    private func sqDeg(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dLat = a.latitude - b.latitude
        let dLon = a.longitude - b.longitude
        return dLat * dLat + dLon * dLon
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

        var firstError: Error?
        let named: [TrailResult]
        let area: [TrailResult]
        do { named = try await namedTask } catch { named = []; firstError = error }
        do { area = try await geoTask } catch { area = []; if firstError == nil { firstError = error } }

        // If both paths failed with an error, surface it so the UI shows "Search failed"
        if named.isEmpty && area.isEmpty, let error = firstError { throw error }

        var seen = Set<String>()
        var merged: [TrailResult] = []
        for trail in named + area where seen.insert(trail.id).inserted {
            merged.append(trail)
        }

        // Balance across categories so short-walk segments don't crowd out longer trails
        var byCategory: [TrailCategory: [TrailResult]] = [:]
        for trail in merged {
            byCategory[trail.category, default: []].append(trail)
        }
        var balanced: [TrailResult] = []
        for category in TrailCategory.allCases {
            balanced.append(contentsOf: (byCategory[category] ?? []).prefix(15))
        }
        return balanced
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
