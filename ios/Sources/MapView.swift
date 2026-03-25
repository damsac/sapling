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
        MapView(camera: $camera, styleURL: styleURL) {
            // Track polyline — only render when we have at least 2 points
            if trackCoordinates.count >= 2 {
                let polyline = MLNPolyline(
                    coordinates: trackCoordinates,
                    count: UInt(trackCoordinates.count)
                )

                ShapeSource(identifier: "trail") {
                    polyline
                }

                LineStyleLayer(identifier: "trail-line", source: "trail")
                    .lineColor(.constant(.blue))
                    .lineWidth(.constant(4))
                    .lineCap(.constant(.round))
                    .lineJoin(.constant(.round))
            }
        }
        .mapControls {
            CompassView()
            LogoView()
                .position(.bottomLeading)
            AttributionButton()
                .position(.bottomTrailing)
        }
        .onAppear {
            if let location = userLocation {
                camera = .center(location.coordinate, zoom: 15)
            }
        }
        .onChange(of: userLocation?.coordinate.latitude) { _, _ in
            if let location = userLocation {
                camera = .center(location.coordinate, zoom: 15)
            }
        }
    }

    private var styleURL: URL {
        URL(string: "https://tiles.openfreemap.org/styles/liberty")!
    }
}
