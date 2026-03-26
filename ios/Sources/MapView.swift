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

    @State private var camera: MapViewCamera = .center(
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        zoom: 14
    )
    @State private var hasInitiallyNavigated = false

    var body: some View {
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
        }
        .onChange(of: userLocation?.coordinate.latitude) { _, _ in
            // Center on user location exactly once — when the first GPS fix arrives.
            // After that, the user has full control of pan and zoom.
            if let coordinate = userLocation?.coordinate, !hasInitiallyNavigated {
                camera = .center(coordinate, zoom: 15)
                hasInitiallyNavigated = true
            }
        }
    }

    private var styleURL: URL {
        URL(string: "https://tiles.openfreemap.org/styles/liberty")!
    }

    // MARK: - Zoom-Adaptive Tap Detection

    /// Extract the current zoom level from the camera state.
    /// Falls back to 14 (our default) for bounding-box / showcase states
    /// where zoom is computed implicitly.
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

    /// Convert a screen-space tap radius (in points) to meters at the given
    /// coordinate and zoom level.
    ///
    /// Seed circles render at a fixed pixel size (radius 11-14 pt) regardless
    /// of zoom. At wide zoom (10-12) the old fixed 50 m threshold covered
    /// only a few pixels — too small for a fingertip. This function scales
    /// the hit-test radius so it always matches the visual marker size.
    ///
    /// Formula: metersPerPoint = 156543.03 * cos(lat) / 2^zoom
    /// (standard Web Mercator relationship at 1x screen scale)
    ///
    /// We use 22 pt (~half a fingertip) as the tap radius and clamp the
    /// result between 30 m (don't shrink below a reasonable minimum) and
    /// 500 m (don't select seeds across the whole screen at zoom 8).
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

    /// Build an array of MLNPointFeature from the current seeds list.
    /// Always returns at least one feature (a hidden placeholder) so the
    /// ShapeSource is never empty.
    private func seedPointFeatures() -> [MLNPointFeature] {
        if seeds.isEmpty {
            // Placeholder so ShapeSource has content
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

    /// Find the seed nearest to a tap coordinate within the given threshold.
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
