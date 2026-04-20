import CoreLocation
import MapLibre
import MapLibreSwiftDSL
import MapLibreSwiftUI
import SwiftUI

struct TripDetailView: View {
    let trip: FfiTripSummary
    let viewModel: TripListViewModel

    @State private var trackCoordinates: [CLLocationCoordinate2D] = []
    @State private var trackPoints: [FfiTrackPoint] = []
    @State private var gpxURL: URL? = nil
    @State private var showShareSheet = false

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    gpxURL = viewModel.exportGpx(trip: trip)
                    if gpxURL != nil { showShareSheet = true }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = gpxURL {
                ShareSheet(url: url)
            }
        }
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
                .lineColor(SaplingColors.trailUI)
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
        VStack(spacing: 0) {
            // Brand accent bar at top of card
            RoundedRectangle(cornerRadius: 2)
                .fill(SaplingColors.brand)
                .frame(height: 3)
                .padding(.horizontal, 24)
                .padding(.bottom, 14)

            HStack(spacing: 0) {
                DetailStat(value: formatDistance(trip.distanceM), label: "Distance")
                Divider().frame(height: 32)
                DetailStat(value: formatDuration(trip.durationMs), label: "Time")
                Divider().frame(height: 32)
                DetailStat(value: "+\(formatElevation(trip.elevationGain))", label: "Gain")
                Divider().frame(height: 32)
                DetailStat(value: "-\(formatElevation(trip.elevationLoss))", label: "Loss")
            }
            .padding(.bottom, 14)

            if !trackPoints.isEmpty {
                ElevationProfileView(trackPoints: trackPoints)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            if trip.seedCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.caption)
                        .foregroundStyle(SaplingColors.brand)
                    Text("\(trip.seedCount) seed\(trip.seedCount == 1 ? "" : "s") dropped")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 12)
            }
        }
        .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
    }

    // MARK: - Data Loading

    private func loadTrack() {
        let points = viewModel.getTrackPoints(tripId: trip.id)
        trackPoints = points
        trackCoordinates = points.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }
}

private struct DetailStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.monospacedDigit())
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
