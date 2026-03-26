import CoreLocation
import MapLibre
import MapLibreSwiftDSL
import MapLibreSwiftUI
import SwiftUI

struct TrailMapView: View {
    let trackCoordinates: [CLLocationCoordinate2D]
    let userLocation: CLLocation?
    let seeds: [FfiSeed]
    var onLongPress: ((CLLocationCoordinate2D) -> Void)? = nil
    var onSeedTapped: ((FfiSeed) -> Void)? = nil

    /// Pending seed for quick-drop overlay (draggable, not yet saved).
    var pendingSeed: PendingSeed? = nil
    var onPendingSeedDrag: ((CLLocationCoordinate2D) -> Void)? = nil
    var onPendingSeedConfirm: (() -> Void)? = nil
    var onPendingSeedCancel: (() -> Void)? = nil

    /// Callback providing the approximate visible bounding box when the camera changes.
    var onVisibleBoundsChanged: ((MLNCoordinateBounds) -> Void)? = nil

    @State private var camera: MapViewCamera = .center(
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        zoom: 14
    )
    @State private var hasInitiallyNavigated = false

    /// Drag offset for the pending seed pin (in points, from its dropped position).
    @State private var pendingDragOffset: CGSize = .zero
    /// Whether the user is actively dragging the pending pin.
    @State private var isDraggingPending: Bool = false
    /// Drives the pulsing animation on the pending pin.
    @State private var isPulsing: Bool = false

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
                        .lineColor(.systemBlue)
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
                }
                .mapControls {
                    CompassView()
                    LogoView()
                        .position(.bottomLeft)
                    AttributionButton()
                        .position(.bottomRight)
                }
                .onTapMapGesture(onTapChanged: { context in
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
                }
                .onChange(of: userLocation?.coordinate.latitude) { _, _ in
                    if let coordinate = userLocation?.coordinate, !hasInitiallyNavigated {
                        camera = .center(coordinate, zoom: 15)
                        hasInitiallyNavigated = true
                    }
                }
                .onChange(of: cameraCenter.latitude) { _, _ in
                    onVisibleBoundsChanged?(visibleBounds(in: geo.size))
                }
                .onChange(of: cameraCenter.longitude) { _, _ in
                    onVisibleBoundsChanged?(visibleBounds(in: geo.size))
                }
                .onChange(of: currentZoom) { _, _ in
                    onVisibleBoundsChanged?(visibleBounds(in: geo.size))
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
                                .foregroundStyle(.secondary)
                                .padding(6)
                                .background(.ultraThinMaterial, in: Circle())
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

    /// Compute the approximate bounding box of the visible map area.
    private func visibleBounds(in size: CGSize) -> MLNCoordinateBounds {
        let sw = screenToCoordinate(CGPoint(x: 0, y: size.height), in: size)
        let ne = screenToCoordinate(CGPoint(x: size.width, y: 0), in: size)
        return MLNCoordinateBounds(sw: sw, ne: ne)
    }

    // MARK: - Coordinate ↔ Screen Conversion

    /// Approximate conversion from coordinate to screen position.
    /// Uses the camera center + zoom to compute a Mercator projection.
    private func coordinateToScreen(
        _ coordinate: CLLocationCoordinate2D,
        in size: CGSize
    ) -> CGPoint {
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

    /// Approximate conversion from screen position back to coordinate.
    private func screenToCoordinate(
        _ point: CGPoint,
        in size: CGSize
    ) -> CLLocationCoordinate2D {
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
        let metersPerPt = 156543.03 * cos(latRadians) / pow(2.0, zoom)
        return min(max(metersPerPt * tapRadiusPts, 30), 500)
    }

    // MARK: - Seed Feature Helpers

    private func seedPointFeatures() -> [MLNPointFeature] {
        if seeds.isEmpty {
            let placeholder = MLNPointFeature()
            placeholder.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
            return [placeholder]
        }
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
