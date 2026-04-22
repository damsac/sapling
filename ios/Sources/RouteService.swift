import CoreLocation
import Foundation

// MARK: - API Key
// Get a free key at https://openrouteservice.org (2,000 requests/day free).
// Paste your key below, then rebuild.
private let orsApiKey = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6Ijk0MzJhZDFhOTE0MTQ1NmRiMzk4OWEyYjljYmY4NDQwIiwiaCI6Im11cm11cjY0In0="

// MARK: - RouteService

enum RouteService {
    enum RouteError: Error, LocalizedError {
        case missingApiKey
        case invalidURL
        case badResponse(Int)
        case decodeFailed
        case noRoute

        var errorDescription: String? {
            switch self {
            case .missingApiKey:
                return "Add your OpenRouteService API key to RouteService.swift."
            case .invalidURL:
                return "Invalid routing URL."
            case .badResponse(let code):
                return "Routing server error (HTTP \(code))."
            case .decodeFailed:
                return "Could not decode routing response."
            case .noRoute:
                return "No trail route found between those points."
            }
        }
    }

    // MARK: - Response shapes

    private struct ORSResponse: Decodable {
        let features: [ORSFeature]
    }

    private struct ORSFeature: Decodable {
        let geometry: ORSGeometry
        let properties: ORSProperties
    }

    private struct ORSGeometry: Decodable {
        // Each element is [lon, lat] or [lon, lat, elevation].
        let coordinates: [[Double]]
    }

    private struct ORSProperties: Decodable {
        let summary: ORSSummary
    }

    private struct ORSSummary: Decodable {
        let distance: Double
    }

    // MARK: - Public API

    /// Route on foot/hiking trails between two coordinates using OpenRouteService.
    /// Prefers OSM hiking paths, footways, and tracks over roads.
    static func route(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) async throws -> (path: [CLLocationCoordinate2D], distanceM: Double) {
        guard !orsApiKey.isEmpty, orsApiKey != "YOUR_ORS_API_KEY_HERE" else {
            throw RouteError.missingApiKey
        }

        let url = URL(string: "https://api.openrouteservice.org/v2/directions/foot-hiking/geojson")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue(orsApiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // ORS wants [lon, lat] pairs
        let body: [String: Any] = [
            "coordinates": [
                [start.longitude, start.latitude],
                [end.longitude, end.latitude]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RouteError.badResponse(http.statusCode)
        }

        let decoded: ORSResponse
        do {
            decoded = try JSONDecoder().decode(ORSResponse.self, from: data)
        } catch {
            throw RouteError.decodeFailed
        }

        guard let feature = decoded.features.first else {
            throw RouteError.noRoute
        }

        // Flip [lon, lat, ?elevation] → CLLocationCoordinate2D(lat, lon)
        let path: [CLLocationCoordinate2D] = feature.geometry.coordinates.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }

        guard !path.isEmpty else { throw RouteError.noRoute }

        return (path: path, distanceM: feature.properties.summary.distance)
    }
}
