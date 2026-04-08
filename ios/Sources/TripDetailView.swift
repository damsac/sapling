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
        let center = bounds.center
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

}
