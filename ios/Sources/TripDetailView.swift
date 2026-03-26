import CoreLocation
import MapLibre
import MapLibreSwiftDSL
import MapLibreSwiftUI
import SwiftUI

struct TripDetailView: View {
    let trip: FfiTripSummary
    let viewModel: TripListViewModel

    @State private var trackCoordinates: [CLLocationCoordinate2D] = []

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full map with trail
            if trackCoordinates.isEmpty {
                Color(.systemGroupedBackground)
                    .overlay {
                        ProgressView("Loading trail...")
                    }
            } else {
                trailMap
            }

            // Stats card at bottom
            statsCard
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadTrack() }
    }

    // MARK: - Trail Map

    private var trailMap: some View {
        let bounds = boundingBox(for: trackCoordinates)
        let center = CLLocationCoordinate2D(
            latitude: (bounds.minLat + bounds.maxLat) / 2,
            longitude: (bounds.minLon + bounds.maxLon) / 2
        )
        let zoom = zoomToFit(bounds: bounds)

        return MapView(
            styleURL: URL(string: "https://tiles.openfreemap.org/styles/liberty")!,
            camera: .constant(.center(center, zoom: zoom))
        ) {
            let trailSource = ShapeSource(identifier: "detail-trail") {
                MLNPolylineFeature(coordinates: trackCoordinates)
            }

            LineStyleLayer(identifier: "detail-trail-line", source: trailSource)
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
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(formatDistance(trip.distanceM))
                    .font(.title3.monospacedDigit())
                    .fontWeight(.semibold)
                Text("Distance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 2) {
                Text(formatDuration(trip.durationMs))
                    .font(.title3.monospacedDigit())
                    .fontWeight(.semibold)
                Text("Time")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 2) {
                Text("+\(formatElevation(trip.elevationGain))")
                    .font(.title3.monospacedDigit())
                    .fontWeight(.semibold)
                Text("Gain")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 2) {
                Text("-\(formatElevation(trip.elevationLoss))")
                    .font(.title3.monospacedDigit())
                    .fontWeight(.semibold)
                Text("Loss")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
    }

    // MARK: - Data Loading

    private func loadTrack() {
        let points = viewModel.getTrackPoints(tripId: trip.id)
        trackCoordinates = points.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    // MARK: - Bounding Box Helpers

    private struct BBox {
        var minLat: Double
        var maxLat: Double
        var minLon: Double
        var maxLon: Double
    }

    private func boundingBox(for coords: [CLLocationCoordinate2D]) -> BBox {
        guard let first = coords.first else {
            return BBox(minLat: 0, maxLat: 0, minLon: 0, maxLon: 0)
        }
        var bbox = BBox(
            minLat: first.latitude, maxLat: first.latitude,
            minLon: first.longitude, maxLon: first.longitude
        )
        for c in coords {
            bbox.minLat = min(bbox.minLat, c.latitude)
            bbox.maxLat = max(bbox.maxLat, c.latitude)
            bbox.minLon = min(bbox.minLon, c.longitude)
            bbox.maxLon = max(bbox.maxLon, c.longitude)
        }
        return bbox
    }

    private func zoomToFit(bounds: BBox) -> Double {
        let latSpan = bounds.maxLat - bounds.minLat
        let lonSpan = bounds.maxLon - bounds.minLon
        let span = max(latSpan, lonSpan)
        guard span > 0 else { return 15 }
        let paddedSpan = span * 1.4
        let zoom = log2(360.0 / paddedSpan)
        return min(max(zoom, 1), 18)
    }
}
