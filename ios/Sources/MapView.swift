import CoreLocation
import MapLibre
import MapLibreSwiftDSL
import MapLibreSwiftUI
import SwiftUI

struct TrailMapView: View {
    let trackCoordinates: [CLLocationCoordinate2D]
    let userLocation: CLLocation?

    @State private var camera: MapViewCamera = .center(
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        zoom: 14
    )

    var body: some View {
        MapView(styleURL: styleURL, camera: $camera) {
            // ShapeSource must be a let binding — MapViewContentBuilder
            // cannot handle it as a direct expression
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
        }
        .mapControls {
            CompassView()
            LogoView()
                .position(.bottomLeft)
            AttributionButton()
                .position(.bottomRight)
        }
        .onAppear {
            // Switch to tracking once location is available
            if userLocation != nil {
                camera = .trackUserLocation(zoom: 15)
            }
        }
        .onChange(of: userLocation?.coordinate.latitude) { _, _ in
            // Lock to user tracking on first location fix (prevents grey screen on startup)
            if userLocation != nil {
                camera = .trackUserLocation(zoom: 15)
            }
        }
    }

    private var styleURL: URL {
        URL(string: "https://tiles.openfreemap.org/styles/liberty")!
    }
}
