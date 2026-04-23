import CoreLocation
import MapLibre
import MapLibreSwiftDSL
import MapLibreSwiftUI
import SwiftUI

private class RouteBuildingProxy {
    var isBuilding = false
    var addWaypoint: ((CLLocationCoordinate2D) -> Void)?
}

struct TrailMapView: View {
    let trackCoordinates: [CLLocationCoordinate2D]
    let userLocation: CLLocation?
    let userHeading: CLHeading?
    let seeds: [FfiSeed]
    var onLongPress: ((CLLocationCoordinate2D) -> Void)? = nil
    var onSeedTapped: ((FfiSeed) -> Void)? = nil

    /// Route builder mode — when true, taps add waypoints instead of selecting seeds
    var isRouteBuilding: Bool = false
    /// The tapped waypoint coordinates — used to render the pin dots.
    var routeWaypoints: [CLLocationCoordinate2D]? = nil
    /// The routed path polyline (snapped to roads/trails). When nil, the
    /// polyline falls back to straight lines between `routeWaypoints`.
    var routePath: [CLLocationCoordinate2D]? = nil
    var onRouteWaypointAdded: ((CLLocationCoordinate2D) -> Void)? = nil
    /// True while a routing request is in flight — shows a small spinner.
    var isRouting: Bool = false

    /// A saved route to display on the map (view mode)
    var displayRoute: [CLLocationCoordinate2D]? = nil

    /// Pending seed for quick-drop overlay (draggable, not yet saved).
    var pendingSeed: PendingSeed? = nil
    var onPendingSeedDrag: ((CLLocationCoordinate2D) -> Void)? = nil
    var onPendingSeedConfirm: (() -> Void)? = nil
    var onPendingSeedCancel: (() -> Void)? = nil

    /// Callback providing the approximate visible bounding box when the camera changes.
    var onVisibleBoundsChanged: ((MLNCoordinateBounds) -> Void)? = nil

    /// Toggled by parent to trigger snapping camera to user location.
    @Binding var snapToLocationTrigger: Bool

    @State private var camera: MapViewCamera = .center(
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        zoom: 14
    )
    @State private var hasInitiallyNavigated = false
    /// Live snapshot of the map's projection, so overlays use MapLibre's real
    /// coordinate→point conversion instead of a hand-rolled approximation.
    @State private var mapProxy: MapViewProxy?
    /// Direct reference to the underlying MLNMapView, captured via the
    /// unsafe modifier. Used for accurate screen↔coordinate conversion in
    /// the route-building tap overlay.
    @State private var mlnMapView: MLNMapView?

    /// Drag offset for the pending seed pin (in points, from its dropped position).
    @State private var pendingDragOffset: CGSize = .zero
    /// Whether the user is actively dragging the pending pin.
    @State private var isDraggingPending: Bool = false
    /// Drives the pulsing animation on the pending pin.
    @State private var isPulsing: Bool = false
    /// Debounce task for visible bounds updates.
    @State private var boundsUpdateTask: Task<Void, Never>?
    /// Reference-type proxy so the onTapMapGesture closure — registered once
    /// at map creation — always sees current building state without re-registration.
    @State private var routeProxy = RouteBuildingProxy()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                MapView(styleURL: styleURL, camera: $camera) {
                    // Trail polyline — ShapeSource must be a let binding
                    let trailSource = ShapeSource(identifier: "trail") {
                        // Must use MLNPolylineFeature (not MLNPolyline) for ShapeSource
                        MLNPolylineFeature(
                            coordinates: trackCoordinates.isEmpty
                                ? [CLLocationCoordinate2D(latitude: 0, longitude: 0)]
                                : trackCoordinates
                        )
                    }

                    // Style modifiers take direct values, not .constant() wrapped
                    LineStyleLayer(identifier: "trail-line", source: trailSource)
                        .lineColor(SaplingColors.trailUI)
                        .lineWidth(4)
                        .lineCap(.round)
                        .lineJoin(.round)

                    // Seed markers — all seed points in one source, filtered by type per layer
                    let seedPoints = seedPointFeatures()
                    let seedSource = ShapeSource(identifier: "seeds") {
                        seedPoints
                    }

                    // White border ring behind all seed dots
                    CircleStyleLayer(identifier: "seed-border", source: seedSource)
                        .radius(14)
                        .color(.white)
                        .strokeWidth(0)
                        .predicate(NSPredicate(format: "seedType != nil"))

                    // One colored circle layer per seed type, filtered by predicate
                    CircleStyleLayer(identifier: "seed-water", source: seedSource)
                        .radius(11)
                        .color(FfiSeedType.water.uiColor)
                        .strokeWidth(0)
                        .predicate(NSPredicate(format: "seedType == %@", "Water"))

                    CircleStyleLayer(identifier: "seed-camp", source: seedSource)
                        .radius(11)
                        .color(FfiSeedType.camp.uiColor)
                        .strokeWidth(0)
                        .predicate(NSPredicate(format: "seedType == %@", "Camp"))

                    CircleStyleLayer(identifier: "seed-beauty", source: seedSource)
                        .radius(11)
                        .color(FfiSeedType.beauty.uiColor)
                        .strokeWidth(0)
                        .predicate(NSPredicate(format: "seedType == %@", "Beauty"))

                    CircleStyleLayer(identifier: "seed-service", source: seedSource)
                        .radius(11)
                        .color(FfiSeedType.service.uiColor)
                        .strokeWidth(0)
                        .predicate(NSPredicate(format: "seedType == %@", "Service"))

                    CircleStyleLayer(identifier: "seed-custom", source: seedSource)
                        .radius(11)
                        .color(FfiSeedType.custom.uiColor)
                        .strokeWidth(0)
                        .predicate(NSPredicate(format: "seedType == %@", "Custom"))

                    // Route builder / display polyline — shown when building or viewing a route.
                    // Prefer the snapped `routePath` when available; fall back to straight
                    // lines between `routeWaypoints` (e.g. during the first segment's
                    // routing request), or the saved route being viewed.
                    let routeCoords = routePath ?? routeWaypoints ?? displayRoute ?? []
                    let routeSource = ShapeSource(identifier: "route-line") {
                        MLNPolylineFeature(
                            coordinates: routeCoords.isEmpty
                                ? [CLLocationCoordinate2D(latitude: 0, longitude: 0)]
                                : routeCoords
                        )
                    }
                    LineStyleLayer(identifier: "route-line-layer", source: routeSource)
                        .lineColor(UIColor(SaplingColors.brand))
                        .lineWidth(routeCoords.isEmpty ? 0 : 3)
                        .lineDashPattern([2, 1.5])
                        .lineCap(.round)
                        .lineJoin(.round)

                    // User location blue dot — drawn above seeds so it's always visible.
                    let userPoints = userLocationFeatures()
                    let userSource = ShapeSource(identifier: "user-location") {
                        userPoints
                    }

                    CircleStyleLayer(identifier: "user-location-halo", source: userSource)
                        .radius(10)
                        .color(.white)
                        .strokeWidth(0)

                    CircleStyleLayer(identifier: "user-location-dot", source: userSource)
                        .radius(7)
                        .color(.systemBlue)
                        .strokeWidth(0)
                }
                .mapControls {
                    CompassView()
                    LogoView()
                        .position(.bottomLeft)
                    AttributionButton()
                        .position(.bottomRight)
                }
                .onTapMapGesture(onTapChanged: { context in
                    if routeProxy.isBuilding {
                        routeProxy.addWaypoint?(context.coordinate)
                        return
                    }
                    let threshold = tapThresholdMeters(
                        at: context.coordinate,
                        zoom: currentZoom
                    )
                    if let tappedSeed = findNearestSeed(to: context.coordinate, threshold: threshold) {
                        onSeedTapped?(tappedSeed)
                    }
                })
                .onLongPressMapGesture(onPressChanged: { context in
                    guard context.state == .began else { return }
                    onLongPress?(context.coordinate)
                })
                .onAppear {
                    if let coordinate = userLocation?.coordinate, !hasInitiallyNavigated {
                        camera = .center(coordinate, zoom: 15)
                        hasInitiallyNavigated = true
                    }
                    onVisibleBoundsChanged?(visibleBounds(in: geo.size))
                    routeProxy.isBuilding = isRouteBuilding
                    routeProxy.addWaypoint = onRouteWaypointAdded
                }
                .onChange(of: isRouteBuilding) { _, new in
                    routeProxy.isBuilding = new
                    routeProxy.addWaypoint = new ? onRouteWaypointAdded : nil
                }
                .onChange(of: userLocation?.coordinate.latitude) { _, _ in
                    if let coordinate = userLocation?.coordinate, !hasInitiallyNavigated {
                        camera = .center(coordinate, zoom: 15)
                        hasInitiallyNavigated = true
                    }
                }
                .onChange(of: cameraCenter.latitude) { _, _ in
                    scheduleBoundsUpdate(in: geo.size)
                }
                .onChange(of: cameraCenter.longitude) { _, _ in
                    scheduleBoundsUpdate(in: geo.size)
                }
                .onChange(of: currentZoom) { _, _ in
                    scheduleBoundsUpdate(in: geo.size)
                }
                .onChange(of: snapToLocationTrigger) { _, _ in
                    if let coordinate = userLocation?.coordinate {
                        camera = .center(coordinate, zoom: max(currentZoom, 15))
                    }
                }
                .onMapViewProxyUpdate(updateMode: .realtime) { proxy in
                    mapProxy = proxy
                }
                .unsafeMapViewControllerModifier { controller in
                    // Keep the map north-up. Rotation would break the overlay
                    // math and also conflict with the spatial-awareness goal
                    // (orient yourself to the world, not the screen).
                    controller.mapView.isRotateEnabled = false
                    controller.mapView.isPitchEnabled = false
                    // Capture the MLNMapView so we can use its exact
                    // screen↔coordinate projection for tap hit-testing.
                    mlnMapView = controller.mapView
                }

                // MARK: - Waypoint Pin Overlays
                // Rendered in SwiftUI so dots appear immediately on first tap
                // without waiting for MapLibre layer updates.
                ForEach(Array((routeWaypoints ?? []).enumerated()), id: \.offset) { idx, coord in
                    let screenPos = coordinateToScreen(coord, in: geo.size)
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 22, height: 22)
                        Circle()
                            .fill(SaplingColors.brand)
                            .frame(width: 15, height: 15)
                    }
                    .position(screenPos)
                    .allowsHitTesting(false)
                }

                // MARK: - Routing Spinner

                // Subtle loading indicator while a route segment is being
                // fetched from the router. Sits at top-center of the map.
                if isRouteBuilding && isRouting {
                    VStack {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Routing…")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(SaplingColors.ink)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(SaplingColors.parchment.opacity(0.92), in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                        .padding(.top, 12)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }

                // MARK: - Heading Wedge

                // A small arrow anchored to the user-location dot, rotated to
                // show where the phone is pointing. Hidden until the compass
                // has a valid reading (negative headingAccuracy = uncalibrated).
                if let userCoord = userLocation?.coordinate,
                   let heading = userHeading,
                   heading.headingAccuracy >= 0 {
                    let screenPos = coordinateToScreen(userCoord, in: geo.size)
                    let direction = heading.trueHeading >= 0
                        ? heading.trueHeading
                        : heading.magneticHeading
                    // Arrow sits 16pt from the dot, in the heading direction.
                    // North is up, positive Y is down, so cos flips sign.
                    let radians = direction * .pi / 180
                    let offsetX = sin(radians) * 16
                    let offsetY = -cos(radians) * 16

                    ZStack {
                        // White outline so the arrow reads on any map style
                        Image(systemName: "arrowtriangle.up.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                        Image(systemName: "arrowtriangle.up.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                    }
                    .rotationEffect(.degrees(direction))
                    .position(x: screenPos.x + offsetX, y: screenPos.y + offsetY)
                    .allowsHitTesting(false)
                }

                // MARK: - Pending Seed Overlay

                if let pending = pendingSeed {
                    let screenPos = coordinateToScreen(
                        pending.coordinate,
                        in: geo.size
                    )

                    // Draggable pin
                    VStack(spacing: 0) {
                        // Pin head
                        Circle()
                            .fill(pending.type.color)
                            .frame(width: 28, height: 28)
                            .overlay {
                                Image(systemName: pending.type.sfSymbol)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            }
                            .overlay {
                                Circle()
                                    .stroke(.white, lineWidth: 2.5)
                            }
                            .shadow(color: pending.type.color.opacity(0.5), radius: 8)
                            // Scale up while dragging, pulse otherwise
                            .scaleEffect(isDraggingPending ? 1.3 : (isPulsing ? 1.15 : 1.0))
                            .animation(
                                isDraggingPending
                                    ? .easeOut(duration: 0.1)
                                    : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: isPulsing
                            )
                            .onAppear { isPulsing = true }
                            .onDisappear { isPulsing = false }

                        // Pin tail
                        Triangle()
                            .fill(pending.type.color)
                            .frame(width: 10, height: 6)
                    }
                    .position(
                        x: screenPos.x + pendingDragOffset.width,
                        y: screenPos.y + pendingDragOffset.height - 20 // offset so pin tip = coordinate
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingPending = true
                                pendingDragOffset = value.translation
                            }
                            .onEnded { value in
                                isDraggingPending = false
                                let finalScreenX = screenPos.x + value.translation.width
                                let finalScreenY = screenPos.y + value.translation.height
                                let newCoord = screenToCoordinate(
                                    CGPoint(x: finalScreenX, y: finalScreenY),
                                    in: geo.size
                                )
                                pendingDragOffset = .zero
                                onPendingSeedDrag?(newCoord)
                            }
                    )

                    // Save chip near the pin
                    HStack(spacing: 12) {
                        Button {
                            onPendingSeedConfirm?()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                Text("Save")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(pending.type.color, in: Capsule())
                        }

                        Button {
                            onPendingSeedCancel?()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(SaplingColors.bark)
                                .padding(6)
                                .background(SaplingColors.parchment.opacity(0.92), in: Circle())
                        }
                    }
                    .position(
                        x: screenPos.x + pendingDragOffset.width,
                        y: screenPos.y + pendingDragOffset.height + 24
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .onChange(of: pendingSeed) { _, _ in
                pendingDragOffset = .zero
                isDraggingPending = false
                isPulsing = false
            }
        }
    }

    private var styleURL: URL {
        URL(string: "https://tiles.openfreemap.org/styles/liberty")!
    }

    // MARK: - Visible Bounds

    /// Debounce visible bounds updates to avoid excessive recomputation during panning.
    private func scheduleBoundsUpdate(in size: CGSize) {
        boundsUpdateTask?.cancel()
        boundsUpdateTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            onVisibleBoundsChanged?(visibleBounds(in: size))
        }
    }

    /// Compute the approximate bounding box of the visible map area.
    private func visibleBounds(in size: CGSize) -> MLNCoordinateBounds {
        let sw = screenToCoordinate(CGPoint(x: 0, y: size.height), in: size)
        let ne = screenToCoordinate(CGPoint(x: size.width, y: 0), in: size)
        return MLNCoordinateBounds(sw: sw, ne: ne)
    }

    // MARK: - Coordinate ↔ Screen Conversion

    /// Convert a geographic coordinate to a screen point.
    /// Prefers MapLibre's real projection via MapViewProxy (accurate under
    /// pan/zoom); falls back to a Web Mercator approximation during the brief
    /// window before the proxy is populated.
    private func coordinateToScreen(
        _ coordinate: CLLocationCoordinate2D,
        in size: CGSize
    ) -> CGPoint {
        if let proxy = mapProxy {
            return proxy.convert(coordinate, toPointTo: nil)
        }

        let center = cameraCenter
        let scale = pow(2.0, currentZoom) * 256 / 360

        let dx = (coordinate.longitude - center.longitude) * scale
        let centerLatRad = center.latitude * .pi / 180
        let coordLatRad = coordinate.latitude * .pi / 180
        let dy = (log(tan(.pi / 4 + centerLatRad / 2)) - log(tan(.pi / 4 + coordLatRad / 2)))
            * (256 * pow(2.0, currentZoom)) / (2 * .pi)

        return CGPoint(
            x: size.width / 2 + dx,
            y: size.height / 2 + dy
        )
    }

    /// Convert a screen point back to a geographic coordinate.
    /// Uses MapLibre's real projection when the underlying `MLNMapView` has
    /// been captured; falls back to a Web Mercator approximation in the
    /// brief window before the mapView reference is populated.
    private func screenToCoordinate(
        _ point: CGPoint,
        in size: CGSize
    ) -> CLLocationCoordinate2D {
        if let mapView = mlnMapView {
            return mapView.convert(point, toCoordinateFrom: mapView)
        }

        let center = cameraCenter
        let scale = pow(2.0, currentZoom) * 256 / 360

        let dx = point.x - size.width / 2
        let longitude = center.longitude + dx / scale

        let dy = point.y - size.height / 2
        let centerLatRad = center.latitude * .pi / 180
        let mercY = log(tan(.pi / 4 + centerLatRad / 2))
            - dy * (2 * .pi) / (256 * pow(2.0, currentZoom))
        let latitude = (2 * atan(exp(mercY)) - .pi / 2) * 180 / .pi

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // MARK: - Camera Helpers

    private var cameraCenter: CLLocationCoordinate2D {
        switch camera.state {
        case .centered(let coord, _, _, _, _):
            return coord
        case .trackingUserLocation(_, _, _, _),
             .trackingUserLocationWithHeading(_, _, _),
             .trackingUserLocationWithCourse(_, _, _):
            return userLocation?.coordinate
                ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        default:
            return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        }
    }

    // MARK: - Zoom-Adaptive Tap Detection

    private var currentZoom: Double {
        switch camera.state {
        case .centered(_, let zoom, _, _, _):
            return zoom
        case .trackingUserLocation(let zoom, _, _, _):
            return zoom
        case .trackingUserLocationWithHeading(let zoom, _, _):
            return zoom
        case .trackingUserLocationWithCourse(let zoom, _, _):
            return zoom
        default:
            return 14
        }
    }

    private func tapThresholdMeters(
        at coordinate: CLLocationCoordinate2D,
        zoom: Double
    ) -> CLLocationDistance {
        let tapRadiusPts: Double = 22
        let latRadians = coordinate.latitude * .pi / 180
        // metersPerPixel at this zoom and latitude (Web Mercator)
        let metersPerPixel = 156543.03 * cos(latRadians) / pow(2.0, zoom)
        // Convert points to pixels via screen scale, then to meters
        let metersPerPt = metersPerPixel / UIScreen.main.scale
        return min(max(metersPerPt * tapRadiusPts, 5), 200)
    }

    // MARK: - Seed Feature Helpers

    private func userLocationFeatures() -> [MLNPointFeature] {
        guard let coord = userLocation?.coordinate else { return [] }
        let feature = MLNPointFeature()
        feature.coordinate = coord
        return [feature]
    }

    private func seedPointFeatures() -> [MLNPointFeature] {
        return seeds.map { seed in
            let feature = MLNPointFeature()
            feature.coordinate = CLLocationCoordinate2D(
                latitude: seed.latitude,
                longitude: seed.longitude
            )
            feature.attributes = [
                "id": seed.id,
                "seedType": seed.seedType.displayName,
                "title": seed.title,
            ]
            return feature
        }
    }

    private func findNearestSeed(
        to coordinate: CLLocationCoordinate2D,
        threshold: CLLocationDistance
    ) -> FfiSeed? {
        let tapLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        var nearest: FfiSeed?
        var nearestDistance: CLLocationDistance = .greatestFiniteMagnitude

        for seed in seeds {
            let seedLocation = CLLocation(latitude: seed.latitude, longitude: seed.longitude)
            let distance = tapLocation.distance(from: seedLocation)
            if distance < nearestDistance {
                nearestDistance = distance
                nearest = seed
            }
        }

        if nearestDistance < threshold {
            return nearest
        }
        return nil
    }
}

// MARK: - Triangle Shape (for pin tail)

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
