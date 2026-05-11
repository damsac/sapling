import CoreLocation
import Observation

@Observable
class RouteBuilderViewModel {
    var waypoints: [CLLocationCoordinate2D] = []
    /// Routed segments as full RoutePoints (coordinate + elevation).
    var routeSegments: [[RoutePoint]] = []
    var segmentDistances: [Double] = []
    var isRouting: Bool = false
    var isBuilding: Bool = false
    var savedRoutes: [FfiRoute] = []
    var lastError: String?

    private let core: SaplingCore

    init(core: SaplingCore) {
        self.core = core
    }

    var distanceMeters: Double {
        segmentDistances.reduce(0, +)
    }

    /// Flat coordinate array for map rendering (no duplicate join points).
    var fullRouteCoordinates: [CLLocationCoordinate2D] {
        guard !routeSegments.isEmpty else { return [] }
        var out: [CLLocationCoordinate2D] = []
        for (i, seg) in routeSegments.enumerated() {
            let coords = seg.map(\.coordinate)
            out.append(contentsOf: i == 0 ? coords : Array(coords.dropFirst()))
        }
        return out
    }

    /// Flat RoutePoint array (coordinate + elevation) for saving and profile.
    var fullRoutePoints: [RoutePoint] {
        guard !routeSegments.isEmpty else { return [] }
        var out: [RoutePoint] = []
        for (i, seg) in routeSegments.enumerated() {
            out.append(contentsOf: i == 0 ? seg : Array(seg.dropFirst()))
        }
        return out
    }

    func startBuilding() {
        waypoints = []
        routeSegments = []
        segmentDistances = []
        isRouting = false
        isBuilding = true
    }
    

    func addWaypoint(_ coordinate: CLLocationCoordinate2D) {
        let previous = waypoints.last
        waypoints.append(coordinate)
        guard let from = previous else { return }

        isRouting = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isRouting = false }
            do {
                let segment = try await RouteService.route(from: from, to: coordinate)
                var pts = segment.points
                pts.insert(RoutePoint(coordinate: from, elevation: pts.first?.elevation), at: 0)
                pts.append(RoutePoint(coordinate: coordinate, elevation: pts.last?.elevation))
                self.routeSegments.append(pts)
                self.segmentDistances.append(segment.distanceM)
            } catch {
                self.routeSegments.append([
                    RoutePoint(coordinate: from, elevation: nil),
                    RoutePoint(coordinate: coordinate, elevation: nil)
                ])
                self.segmentDistances.append(haversine(from, coordinate))
                self.lastError = "Couldn't snap to trail — using straight line."
            }
        }
    }

    func undoLast() {
        guard !waypoints.isEmpty else { return }
        waypoints.removeLast()
        if !routeSegments.isEmpty { routeSegments.removeLast() }
        if !segmentDistances.isEmpty { segmentDistances.removeLast() }
    }

    func cancel() {
        waypoints = []
        routeSegments = []
        segmentDistances = []
        isRouting = false
        isBuilding = false
    }

    func saveRoute(name: String) {
        let pts = fullRoutePoints
        let coordsToSave: [CLLocationCoordinate2D] = pts.isEmpty ? waypoints : pts.map(\.coordinate)
        let elevsToSave: [Double?] = pts.isEmpty ? Array(repeating: nil, count: waypoints.count) : pts.map(\.elevation)

        let ffiWaypoints = zip(coordsToSave, elevsToSave).map { coord, elev in
            FfiRouteWaypoint(latitude: coord.latitude, longitude: coord.longitude, elevation: elev)
        }

        do {
            let route = try core.createRoute(
                name: name,
                waypoints: ffiWaypoints,
                distanceM: distanceMeters
            )
            savedRoutes.insert(route, at: 0)
        } catch {
            lastError = error.localizedDescription
        }
        waypoints = []
        routeSegments = []
        segmentDistances = []
        isRouting = false
        isBuilding = false
    }

    func saveTrailRoute(name: String, coordinates: [CLLocationCoordinate2D], distanceM: Double, elevations: [Double]?) {
        let ffiWaypoints: [FfiRouteWaypoint]
        if let elevs = elevations, elevs.count >= 2, coordinates.count >= 2 {
            ffiWaypoints = coordinates.enumerated().map { i, coord in
                let t = Double(i) / Double(coordinates.count - 1)
                let ei = Int((t * Double(elevs.count - 1)).rounded())
                let clamped = min(max(ei, 0), elevs.count - 1)
                let lo = max(0, clamped - 1)
                let hi = min(elevs.count - 1, clamped + 1)
                let frac = t * Double(elevs.count - 1) - Double(lo)
                let elev = lo == hi ? elevs[lo] : elevs[lo] * (1 - frac) + elevs[hi] * frac
                return FfiRouteWaypoint(latitude: coord.latitude, longitude: coord.longitude, elevation: elev)
            }
        } else {
            ffiWaypoints = coordinates.map {
                FfiRouteWaypoint(latitude: $0.latitude, longitude: $0.longitude, elevation: nil)
            }
        }
        do {
            let route = try core.createRoute(name: name, waypoints: ffiWaypoints, distanceM: distanceM)
            savedRoutes.insert(route, at: 0)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func exportGpx(route: FfiRoute) -> URL? {
        guard let gpxString = try? core.exportRouteGpx(routeId: route.id) else { return nil }
        let safeName = route.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).gpx")
        try? gpxString.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func loadRoutes() {
        do { savedRoutes = try core.listRoutes() }
        catch { lastError = error.localizedDescription }
    }

    func deleteRoute(_ id: String) {
        do {
            try core.deleteRoute(id: id)
            savedRoutes.removeAll { $0.id == id }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func renameRoute(_ id: String, name: String) {
        do {
            try core.renameRoute(id: id, name: name)
            if let idx = savedRoutes.firstIndex(where: { $0.id == id }) {
                let r = savedRoutes[idx]
                savedRoutes[idx] = FfiRoute(
                    id: r.id, name: name, notes: r.notes,
                    waypoints: r.waypoints, distanceM: r.distanceM,
                    createdAt: r.createdAt, updatedAt: r.updatedAt
                )
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}

private func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    let R = 6_371_000.0
    let lat1 = a.latitude * .pi / 180
    let lat2 = b.latitude * .pi / 180
    let dLat = (b.latitude - a.latitude) * .pi / 180
    let dLon = (b.longitude - a.longitude) * .pi / 180
    let x = sin(dLat / 2) * sin(dLat / 2)
        + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
    return R * 2 * atan2(sqrt(x), sqrt(1 - x))
}
