import CoreLocation
import MapLibre
import MapLibreSwiftDSL
import MapLibreSwiftUI
import SwiftUI

struct TrailMapView: View {
    let trackCoordinates: [CLLocationCoordinate2D]
    let userLocation: CLLocation?
    let gems: [FfiGem]
    var onLongPress: ((CLLocationCoordinate2D) -> Void)? = nil
    var onGemTapped: ((FfiGem) -> Void)? = nil

    @State private var camera: MapViewCamera = .center(
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        zoom: 14
    )

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

            // Gem markers — all gem points in one source, filtered by type per layer
            let gemPoints = gemPointFeatures()
            let gemSource = ShapeSource(identifier: "gems") {
                gemPoints
            }

            // White border ring behind all gem dots
            CircleStyleLayer(identifier: "gem-border", source: gemSource)
                .radius(14)
                .color(.white)
                .strokeWidth(0)
                .predicate(NSPredicate(format: "gemType != nil"))

            // One colored circle layer per gem type, filtered by predicate
            CircleStyleLayer(identifier: "gem-water", source: gemSource)
                .radius(11)
                .color(FfiGemType.water.uiColor)
                .strokeWidth(0)
                .predicate(NSPredicate(format: "gemType == %@", "Water"))

            CircleStyleLayer(identifier: "gem-camp", source: gemSource)
                .radius(11)
                .color(FfiGemType.camp.uiColor)
                .strokeWidth(0)
                .predicate(NSPredicate(format: "gemType == %@", "Camp"))

            CircleStyleLayer(identifier: "gem-beauty", source: gemSource)
                .radius(11)
                .color(FfiGemType.beauty.uiColor)
                .strokeWidth(0)
                .predicate(NSPredicate(format: "gemType == %@", "Beauty"))

            CircleStyleLayer(identifier: "gem-service", source: gemSource)
                .radius(11)
                .color(FfiGemType.service.uiColor)
                .strokeWidth(0)
                .predicate(NSPredicate(format: "gemType == %@", "Service"))

            CircleStyleLayer(identifier: "gem-custom", source: gemSource)
                .radius(11)
                .color(FfiGemType.custom.uiColor)
                .strokeWidth(0)
                .predicate(NSPredicate(format: "gemType == %@", "Custom"))
        }
        .mapControls {
            CompassView()
            LogoView()
                .position(.bottomLeft)
            AttributionButton()
                .position(.bottomRight)
        }
        .onLongPressMapGesture { context in
            guard context.state == .began else { return }
            onLongPress?(context.coordinate)
        }
        .onTapMapGesture(on: Set(gemLayerIDs)) { context, features in
            guard !features.isEmpty else { return }
            if let tappedGem = findNearestGem(to: context.coordinate) {
                onGemTapped?(tappedGem)
            }
        }
        .onAppear {
            if userLocation != nil {
                camera = .trackUserLocation(zoom: 15)
            }
        }
        .onChange(of: userLocation?.coordinate.latitude) { _, _ in
            if userLocation != nil {
                camera = .trackUserLocation(zoom: 15)
            }
        }
    }

    private var styleURL: URL {
        URL(string: "https://tiles.openfreemap.org/styles/liberty")!
    }

    /// Layer IDs for tap gesture detection on gem circles.
    private var gemLayerIDs: [String] {
        ["gem-border", "gem-water", "gem-camp", "gem-beauty", "gem-service", "gem-custom"]
    }

    // MARK: - Gem Feature Helpers

    /// Build an array of MLNPointFeature from the current gems list.
    /// Always returns at least one feature (a hidden placeholder) so the
    /// ShapeSource is never empty.
    private func gemPointFeatures() -> [MLNPointFeature] {
        if gems.isEmpty {
            // Placeholder so ShapeSource has content
            let placeholder = MLNPointFeature()
            placeholder.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
            return [placeholder]
        }
        return gems.map { gem in
            let feature = MLNPointFeature()
            feature.coordinate = CLLocationCoordinate2D(
                latitude: gem.latitude,
                longitude: gem.longitude
            )
            feature.attributes = [
                "id": gem.id,
                "gemType": gem.gemType.displayName,
                "title": gem.title,
            ]
            return feature
        }
    }

    /// Find the gem nearest to a tap coordinate.
    private func findNearestGem(to coordinate: CLLocationCoordinate2D) -> FfiGem? {
        let tapLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        var nearest: FfiGem?
        var nearestDistance: CLLocationDistance = .greatestFiniteMagnitude

        for gem in gems {
            let gemLocation = CLLocation(latitude: gem.latitude, longitude: gem.longitude)
            let distance = tapLocation.distance(from: gemLocation)
            if distance < nearestDistance {
                nearestDistance = distance
                nearest = gem
            }
        }

        // Only match within reasonable tap distance
        if nearestDistance < 200 {
            return nearest
        }
        return nil
    }
}
