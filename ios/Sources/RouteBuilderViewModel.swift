import CoreLocation
import Observation

@Observable
class RouteBuilderViewModel {
    /// Tapped waypoints (the pins the user placed).
    var waypoints: [CLLocationCoordinate2D] = []
    /// One routed segment per pair of consecutive waypoints.
    /// `routeSegments[i]` is the path from `waypoints[i]` to `waypoints[i+1]`.
    var routeSegments: [[CLLocationCoordinate2D]] = []
    /// Distance in meters for each routed segment.
    var segmentDistances: [Double] = []
    /// Loading state while a segment is being fetched from the router.
    var isRouting: Bool = false
    var isBuilding: Bool = false
    var savedRoutes: [FfiRoute] = []
    var lastError: String?

    private let core: SaplingCore

    init(core: SaplingCore) {
        self.core = core
    }

    /// Total distance, summing real routed segment distances (not a straight
    /// line between raw waypoints).
    var distanceMeters: Double {
        segmentDistances.reduce(0, +)
    }

    /// The chained full path across all segments, with duplicate join points
    /// removed (each segment's first point duplicates the previous segment's
    /// last point).
    var fullRoutePath: [CLLocationCoordinate2D] {
        guard !routeSegments.isEmpty else { return [] }
        var combined: [CLLocationCoordinate2D] = []
        for (i, segment) in routeSegments.enumerated() {
            if i == 0 {
                combined.append(contentsOf: segment)
            } else {
                // Drop the first coordinate — it equals the previous segment's last.
                combined.append(contentsOf: segment.dropFirst())
            }
        }
        return combined
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

        guard let from = previous else {
            // First waypoint — nothing to route yet.
            return
        }

        let to = coordinate
        isRouting = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isRouting = false }
            do {
                let result = try await RouteService.route(from: from, to: to)
                var path = result.path
                // Anchor to exact tapped coordinates so the route doesn't
                // visually extend past where the user placed their pins.
                path.insert(from, at: 0)
                path.append(to)
                self.routeSegments.append(path)
                self.segmentDistances.append(result.distanceM)
            } catch {
                // Fall back to a straight line so the UX doesn't break.
                self.routeSegments.append([from, to])
                self.segmentDistances.append(haversine(from, to))
                self.lastError = "Couldn't snap to trail — using straight line."
            }
        }
    }

    func undoLast() {
        guard !waypoints.isEmpty else { return }
        waypoints.removeLast()
        if !routeSegments.isEmpty {
            routeSegments.removeLast()
        }
        if !segmentDistances.isEmpty {
            segmentDistances.removeLast()
        }
    }

    func cancel() {
        waypoints = []
        routeSegments = []
        segmentDistances = []
        isRouting = false
        isBuilding = false
    }

    func saveRoute(name: String) {
        // Prefer the full routed path so the saved route preserves the
        // actual snapped geometry, not just the raw pin coordinates. Fall
        // back to raw waypoints if we don't have any routed segments yet
        // (e.g. a single-point "route").
        let path = fullRoutePath
        let coordsToSave: [CLLocationCoordinate2D] = path.isEmpty ? waypoints : path

        let ffiwaypoints = coordsToSave.map {
            FfiRouteWaypoint(latitude: $0.latitude, longitude: $0.longitude)
        }
        do {
            let route = try core.createRoute(
                name: name,
                waypoints: ffiwaypoints,
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

    func loadRoutes() {
        do {
            savedRoutes = try core.listRoutes()
        } catch {
            lastError = error.localizedDescription
        }
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

private func haversine(
    _ a: CLLocationCoordinate2D,
    _ b: CLLocationCoordinate2D
) -> Double {
    let R = 6_371_000.0
    let lat1 = a.latitude * .pi / 180
    let lat2 = b.latitude * .pi / 180
    let dLat = (b.latitude - a.latitude) * .pi / 180
    let dLon = (b.longitude - a.longitude) * .pi / 180
    let x = sin(dLat / 2) * sin(dLat / 2)
        + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
    return R * 2 * atan2(sqrt(x), sqrt(1 - x))
}
