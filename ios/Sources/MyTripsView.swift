import Charts
import CoreLocation
import MapLibre
import MapLibreSwiftDSL
import MapLibreSwiftUI
import SwiftUI
import UniformTypeIdentifiers

struct MyTripsView: View {
    var tripListViewModel: TripListViewModel
    var routeViewModel: RouteBuilderViewModel
    var seedViewModel: SeedViewModel
    let onStartNavigation: (FfiRoute) -> Void
    let onStartBuilding: () -> Void

    @State private var selectedRoute: FfiRoute? = nil
    @State private var showImportPicker = false
    @State private var tripsLimit: Int = 5
    @State private var routesLimit: Int = 5
    private let offlineManager = OfflineMapManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    tripsSection
                    routesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(SaplingColors.stone.ignoresSafeArea())
            .navigationTitle("My Trips")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { tripId in
                if let trip = tripListViewModel.trips.first(where: { $0.id == tripId }) {
                    TripDetailView(trip: trip, viewModel: tripListViewModel)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImportPicker = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    let name = url.deletingPathExtension().lastPathComponent
                    tripListViewModel.importGpx(fileURL: url, name: name.isEmpty ? nil : name)
                }
            }
        }
        .sheet(item: $selectedRoute) { route in
            RouteDetailSheet(
                route: route,
                seeds: seedViewModel.seeds,
                onStartNavigation: { onStartNavigation(route) },
                onStartBuilding: onStartBuilding,
                onDelete: {
                    routeViewModel.deleteRoute(route.id)
                    selectedRoute = nil
                },
                onRename: { name in
                    routeViewModel.renameRoute(route.id, name: name)
                    selectedRoute = nil
                },
                onExportGpx: { routeViewModel.exportGpx(route: route) }
            )
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            tripListViewModel.loadTrips()
            routeViewModel.loadRoutes()
        }
    }

    // MARK: - Recorded Trips Section

    private var tripsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("RECORDED TRIPS") {
                Button {
                    showImportPicker = true
                } label: {
                    Label("Import GPX", systemImage: "plus")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(SaplingColors.accent)
                }
            }

            if tripListViewModel.trips.isEmpty {
                emptyCard(icon: "figure.hiking", message: "No trips yet — hit record and go explore.")
            } else {
                ForEach(tripListViewModel.trips.prefix(tripsLimit), id: \.id) { trip in
                    NavigationLink(value: trip.id) {
                        TripCard(trip: trip)
                    }
                    .buttonStyle(.plain)
                }
                if tripListViewModel.trips.count > tripsLimit {
                    viewMoreButton { tripsLimit += 5 }
                }
            }
        }
    }

    // MARK: - Planned Routes Section

    private var routesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("PLANNED ROUTES") {
                Button {
                    onStartBuilding()
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(SaplingColors.brand)
                }
            }

            if routeViewModel.savedRoutes.isEmpty {
                emptyCard(icon: "map", message: "No saved routes — build one on the Map tab.")
            } else {
                ForEach(routeViewModel.savedRoutes.prefix(routesLimit), id: \.id) { route in
                    Button {
                        selectedRoute = route
                    } label: {
                        let coords = route.waypoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                        RouteCard(route: route, isDownloaded: offlineManager.isRegionDownloaded(coordinates: coords))
                    }
                    .buttonStyle(.plain)
                }
                if routeViewModel.savedRoutes.count > routesLimit {
                    viewMoreButton { routesLimit += 5 }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SaplingColors.bark)
                .kerning(0.8)
            Spacer()
            trailing()
        }
    }

    private func viewMoreButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("View More")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SaplingColors.brand)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(SaplingColors.brand.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func emptyCard(icon: String, message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(SaplingColors.bark.opacity(0.5))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(SaplingColors.bark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Trip Card

private struct TripCard: View {
    let trip: FfiTripSummary

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(SaplingColors.accent)
                .frame(width: 3)
                .frame(minHeight: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SaplingColors.ink)
                Text(tripFormattedDate(trip.createdAt))
                    .font(.caption2)
                    .foregroundStyle(SaplingColors.bark)
                HStack(spacing: 6) {
                    Text(formatDistance(trip.distanceM))
                    Text("·")
                    Text("+\(formatElevation(trip.elevationGain))")
                    Text("·")
                    Text(formatDuration(trip.durationMs))
                }
                .font(.caption2)
                .foregroundStyle(SaplingColors.bark)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SaplingColors.bark.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Route Card

private struct RouteCard: View {
    let route: FfiRoute
    let isDownloaded: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(SaplingColors.brand.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.body)
                    .foregroundStyle(SaplingColors.brand)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(route.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SaplingColors.ink)
                HStack(spacing: 5) {
                    Text(formatDistance(route.distanceM))
                        .font(.caption2)
                        .foregroundStyle(SaplingColors.bark)
                    if isDownloaded {
                        Text("· Offline ready")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(SaplingColors.brand)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SaplingColors.bark.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Route Detail Sheet

struct RouteDetailSheet: View {
    let route: FfiRoute
    let seeds: [FfiSeed]
    let onStartNavigation: () -> Void
    let onStartBuilding: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onExportGpx: () -> URL?

    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var offlineState: OfflineState = .idle
    @State private var trackingPackId: String? = nil
    @State private var gpxUrl: URL? = nil
    private let offlineManager = OfflineMapManager.shared
    @Environment(\.dismiss) private var dismiss

    private enum OfflineState { case idle, inProgress, done }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        route.waypoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
    private var stats: RouteElevationStats { elevationStats(from: route.waypoints) }
    private var difficulty: RouteDifficulty { routeDifficulty(distanceM: route.distanceM, gainM: stats.gain) }
    private var estimatedMinutes: Int { naismithMinutes(distanceM: route.distanceM, elevationGainM: stats.gain) }
    private var nearbySeeds: [SeedOnRoute] { seedsNearRoute(seeds, waypoints: route.waypoints) }
    private var isMultiDay: Bool { estimatedMinutes > 300 }
    private var campRecommendations: [CampRecommendation] {
        let campSeeds = nearbySeeds.filter { $0.seed.seedType == .camp }
        guard campSeeds.isEmpty else { return [] }
        let elevs = route.waypoints.compactMap(\.elevation)
        return computeCampRecommendations(
            coordinates: routeCoordinates,
            elevations: elevs.isEmpty ? nil : elevs,
            totalDistanceM: route.distanceM,
            estimatedMinutes: estimatedMinutes
        )
    }

    private var isDownloaded: Bool {
        offlineState == .done || offlineManager.isRegionDownloaded(coordinates: routeCoordinates)
    }

    private var downloadEstimate: (tileCount: Int, bytes: Int)? {
        guard let bounds = OfflineMapManager.bounds(for: routeCoordinates) else { return nil }
        return OfflineMapManager.estimateSize(bounds: bounds)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(SaplingColors.bark.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 20) {
                    if !routeCoordinates.isEmpty {
                        RouteMapPreview(coordinates: routeCoordinates)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 16)
                    }

                    HStack(alignment: .center) {
                        Text(route.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(SaplingColors.ink)
                        Spacer()
                        DifficultyBadge(difficulty: difficulty)
                    }
                    .padding(.horizontal, 16)

                    HStack(spacing: 0) {
                        RouteStatCell(label: "Distance", value: formatDistance(route.distanceM))
                        Divider().frame(height: 32)
                        RouteStatCell(label: "Est. Time", value: formatDurationMinutes(estimatedMinutes))
                        if stats.hasData {
                            Divider().frame(height: 32)
                            RouteStatCell(label: "Elev. Gain", value: formatElevation(stats.gain))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)

                    if stats.hasData {
                        ElevationProfileCard(elevations: route.waypoints.compactMap(\.elevation), stats: stats)
                            .padding(.horizontal, 16)
                    }

                    if !nearbySeeds.isEmpty {
                        SeedsAlongRouteSection(seeds: nearbySeeds)
                            .padding(.horizontal, 16)
                    }

                    if isMultiDay {
                        DayBreakdownSection(
                            campSeeds: nearbySeeds.filter { $0.seed.seedType == .camp },
                            recommendations: campRecommendations,
                            totalDistanceM: route.distanceM,
                            estimatedMinutes: estimatedMinutes
                        )
                        .padding(.horizontal, 16)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text("Created \(tripFormattedDate(route.createdAt))")
                            .font(.caption)
                    }
                    .foregroundStyle(SaplingColors.bark)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                    if let notes = route.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SaplingColors.bark)
                            Text(notes)
                                .font(.callout)
                                .foregroundStyle(SaplingColors.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    }

                    VStack(spacing: 10) {
                        Button {
                            dismiss()
                            onStartNavigation()
                        } label: {
                            Label("Start Navigation", systemImage: "location.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(SaplingColors.brand, in: RoundedRectangle(cornerRadius: 14))
                        }

                        if !routeCoordinates.isEmpty {
                            if offlineState == .inProgress {
                                VStack(spacing: 6) {
                                    ProgressView(value: offlineManager.activeDownloadProgress)
                                        .tint(SaplingColors.brand)
                                    Text("\(Int(offlineManager.activeDownloadProgress * 100))% downloaded")
                                        .font(.caption)
                                        .foregroundStyle(SaplingColors.bark)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(SaplingColors.bark.opacity(0.2), lineWidth: 1.5)
                                )
                            } else {
                                VStack(spacing: 5) {
                                    Button {
                                        if let id = offlineManager.downloadRegion(name: route.name, coordinates: routeCoordinates) {
                                            offlineState = .inProgress
                                            trackingPackId = id
                                        }
                                    } label: {
                                        Label(
                                            isDownloaded ? "Downloaded" : "Download for Offline",
                                            systemImage: isDownloaded ? "checkmark.circle.fill" : "arrow.down.to.line.circle"
                                        )
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(isDownloaded ? SaplingColors.brand : SaplingColors.bark)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(
                                                    isDownloaded ? SaplingColors.brand.opacity(0.5) : SaplingColors.bark.opacity(0.25),
                                                    lineWidth: 1.5
                                                )
                                        )
                                    }
                                    .disabled(isDownloaded)

                                    if isDownloaded {
                                        if let pack = offlineManager.downloadedPack(for: routeCoordinates) {
                                            Text("z\(Int(pack.minZoom))–\(Int(pack.maxZoom)) · \(pack.formattedSize) saved")
                                                .font(.caption2)
                                                .foregroundStyle(SaplingColors.brand.opacity(0.8))
                                        }
                                    } else if let est = downloadEstimate {
                                        Text("~\(OfflineMapManager.formatEstimatedSize(bytes: est.bytes)) · z10–z16")
                                            .font(.caption2)
                                            .foregroundStyle(SaplingColors.bark.opacity(0.6))
                                    }
                                }
                            }
                        }

                        HStack(spacing: 10) {
                            Button {
                                renameText = route.name
                                showRenameAlert = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(SaplingColors.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 12))
                            }

                            Group {
                                if let url = gpxUrl {
                                    ShareLink(item: url) {
                                        Label("Export GPX", systemImage: "square.and.arrow.up")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(SaplingColors.ink)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 12))
                                    }
                                } else {
                                    Label("Export GPX", systemImage: "square.and.arrow.up")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(SaplingColors.bark.opacity(0.4))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }

                            Button(role: .destructive) {
                                dismiss()
                                onDelete()
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(SaplingColors.stopRecording)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(SaplingColors.stopRecording.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(SaplingColors.parchment.ignoresSafeArea())
        .onAppear { gpxUrl = onExportGpx() }
        .alert("Rename Route", isPresented: $showRenameAlert) {
            TextField("Route name", text: $renameText)
            Button("Save") {
                let name = renameText.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { onRename(name) }
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        }
        .onChange(of: offlineManager.packs) { _, packs in
            guard offlineState == .inProgress, let id = trackingPackId else { return }
            if packs.first(where: { $0.id == id })?.isComplete == true {
                offlineState = .done
            }
        }
    }
}

// MARK: - Date Helper

private func tripFormattedDate(_ iso: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: iso) { return formatTripDate(date) }
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: iso) { return formatTripDate(date) }
    return iso
}

private func formatTripDate(_ date: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(date) {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return "Today, \(f.string(from: date))"
    } else if cal.isDateInYesterday(date) {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return "Yesterday, \(f.string(from: date))"
    } else {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
