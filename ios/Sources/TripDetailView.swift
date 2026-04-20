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
    @State private var seeds: [FfiSeed] = []
    @State private var gpxURL: URL? = nil
    @State private var showShareSheet = false
    @State private var showEditSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if trackCoordinates.isEmpty {
                Color(.systemGroupedBackground)
                    .overlay {
                        ProgressView("Loading trail...")
                    }
            } else {
                trailMap
            }

            statsCard
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    Button {
                        gpxURL = viewModel.exportGpx(trip: trip)
                        if gpxURL != nil { showShareSheet = true }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = gpxURL {
                ShareSheet(url: url)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            TripEditSheet(
                trip: trip,
                onSave: { name, notes in
                    if !name.isEmpty { viewModel.renameTrip(id: trip.id, name: name) }
                    viewModel.updateTripNotes(id: trip.id, notes: notes.isEmpty ? nil : notes)
                    showEditSheet = false
                },
                onCancel: { showEditSheet = false }
            )
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

            if !seeds.isEmpty {
                let seedSource = ShapeSource(identifier: "detail-seeds") {
                    seeds.map { seed in
                        let feature = MLNPointFeature()
                        feature.coordinate = CLLocationCoordinate2D(
                            latitude: seed.latitude, longitude: seed.longitude
                        )
                        feature.attributes = ["seedType": seed.seedType.displayName]
                        return feature
                    }
                }

                CircleStyleLayer(identifier: "detail-seed-border", source: seedSource)
                    .radius(10)
                    .color(.white)
                    .strokeWidth(0)

                CircleStyleLayer(identifier: "detail-seed-water", source: seedSource)
                    .radius(7)
                    .color(FfiSeedType.water.uiColor)
                    .strokeWidth(0)
                    .predicate(NSPredicate(format: "seedType == %@", "Water"))

                CircleStyleLayer(identifier: "detail-seed-camp", source: seedSource)
                    .radius(7)
                    .color(FfiSeedType.camp.uiColor)
                    .strokeWidth(0)
                    .predicate(NSPredicate(format: "seedType == %@", "Camp"))

                CircleStyleLayer(identifier: "detail-seed-beauty", source: seedSource)
                    .radius(7)
                    .color(FfiSeedType.beauty.uiColor)
                    .strokeWidth(0)
                    .predicate(NSPredicate(format: "seedType == %@", "Beauty"))

                CircleStyleLayer(identifier: "detail-seed-service", source: seedSource)
                    .radius(7)
                    .color(FfiSeedType.service.uiColor)
                    .strokeWidth(0)
                    .predicate(NSPredicate(format: "seedType == %@", "Service"))

                CircleStyleLayer(identifier: "detail-seed-custom", source: seedSource)
                    .radius(7)
                    .color(FfiSeedType.custom.uiColor)
                    .strokeWidth(0)
                    .predicate(NSPredicate(format: "seedType == %@", "Custom"))
            }
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

            if let notes = trip.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(SaplingColors.bark)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
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
        seeds = viewModel.getSeedsForTrip(tripId: trip.id)
    }
}

// MARK: - Edit Sheet

private struct TripEditSheet: View {
    let trip: FfiTripSummary
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var notes: String

    init(trip: FfiTripSummary, onSave: @escaping (String, String) -> Void, onCancel: @escaping () -> Void) {
        self.trip = trip
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: trip.name)
        _notes = State(initialValue: trip.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Name") {
                    TextField("Name", text: $name)
                }
                Section("Notes") {
                    TextField("Add notes…", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespaces),
                               notes.trimmingCharacters(in: .whitespaces))
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Stat Cell

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
