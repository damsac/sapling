import CoreLocation
import SwiftUI

struct TrailDetailView: View {
    let trail: TrailResult
    let seedViewModel: SeedViewModel
    var routeViewModel: RouteBuilderViewModel
    let onStartNavigation: ([CLLocationCoordinate2D]) -> Void

    @State private var elevations: [Double]? = nil
    @State private var isLoadingElevation = false
    @State private var showSaveAlert = false
    @State private var saveName = ""
    @State private var isSaved = false
    @State private var offlineState: OfflineState = .idle
    @State private var trackingPackId: String? = nil
    @State private var numDays: Int = 2
    private let offlineManager = OfflineMapManager.shared

    private enum OfflineState { case idle, inProgress, done }

    private var stats: RouteElevationStats {
        elevations.map { elevationStatsFromProfile($0) }
            ?? RouteElevationStats(gain: 0, loss: 0, minElev: 0, maxElev: 0, hasData: false)
    }
    private var gainM: Double { stats.hasData ? stats.gain : trail.elevationGainM }
    private var estimatedMinutes: Int { naismithMinutes(distanceM: trail.distanceM, elevationGainM: gainM) }
    private var difficulty: RouteDifficulty { routeDifficulty(distanceM: trail.distanceM, gainM: gainM) }
    private var nearbySeeds: [SeedOnRoute] { seedsNearRoute(seedViewModel.seeds, coordinates: trail.coordinates) }
    private var isMultiDay: Bool { estimatedMinutes > 300 }

    private var isDownloaded: Bool {
        offlineState == .done || offlineManager.isRegionDownloaded(coordinates: trail.coordinates)
    }

    private var downloadEstimate: (tileCount: Int, bytes: Int)? {
        guard let bounds = OfflineMapManager.bounds(for: trail.coordinates) else { return nil }
        return OfflineMapManager.estimateSize(bounds: bounds)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !trail.coordinates.isEmpty {
                    RouteMapPreview(coordinates: trail.coordinates, sourceId: "trail-\(trail.id)")
                        .frame(height: 220)
                }

                VStack(spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trail.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(SaplingColors.ink)
                            if let network = trail.network {
                                Text(networkLabel(network))
                                    .font(.caption)
                                    .foregroundStyle(SaplingColors.bark)
                            }
                        }
                        Spacer()
                        DifficultyBadge(difficulty: difficulty)
                    }

                    HStack(spacing: 0) {
                        RouteStatCell(label: "Distance", value: formatDistance(trail.distanceM))
                        Divider().frame(height: 32)
                        RouteStatCell(label: "Est. Time", value: formatDurationMinutes(estimatedMinutes))
                        if gainM > 0 {
                            Divider().frame(height: 32)
                            RouteStatCell(label: "Elev. Gain", value: formatElevation(gainM))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 14))

                    trailMetadataRow

                    if isLoadingElevation {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading elevation data…")
                                .font(.caption)
                                .foregroundStyle(SaplingColors.bark)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 14))
                    } else if let elevs = elevations, stats.hasData {
                        ElevationProfileCard(elevations: elevs, stats: stats)
                    }

                    if let description = trail.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("About")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SaplingColors.bark)
                            Text(description)
                                .font(.callout)
                                .foregroundStyle(SaplingColors.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 12))
                    }

                    if !nearbySeeds.isEmpty {
                        SeedsAlongRouteSection(seeds: nearbySeeds)
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.title2)
                                .foregroundStyle(SaplingColors.accent.opacity(0.5))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("No seeds on this trail yet")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(SaplingColors.ink)
                                Text("Be the first to drop a camp spot, water source, or hidden gem.")
                                    .font(.caption2)
                                    .foregroundStyle(SaplingColors.bark.opacity(0.6))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 14))
                    }

                    if isMultiDay {
                        MultiDayPlanSection(
                            coordinates: trail.coordinates,
                            elevations: elevations,
                            seeds: nearbySeeds,
                            numDays: $numDays
                        )
                    }

                    VStack(spacing: 10) {
                        Button {
                            saveName = trail.name
                            showSaveAlert = true
                        } label: {
                            Label(
                                isSaved ? "Saved to My Trips" : "Save to My Trips",
                                systemImage: isSaved ? "bookmark.fill" : "bookmark"
                            )
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isSaved ? SaplingColors.bark : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                isSaved ? SaplingColors.stone : SaplingColors.brand,
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                        }

                        Button {
                            onStartNavigation(trail.coordinates)
                        } label: {
                            Label("Start Navigation", systemImage: "location.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(SaplingColors.brand)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(SaplingColors.brand, lineWidth: 1.5)
                                )
                        }

                        if !trail.coordinates.isEmpty {
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
                                        startDownload()
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
                                        if let pack = offlineManager.downloadedPack(for: trail.coordinates) {
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
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
        .background(SaplingColors.stone.ignoresSafeArea())
        .navigationTitle(trail.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Save Trail", isPresented: $showSaveAlert) {
            TextField("Route name", text: $saveName)
            Button("Save") { performSave() }
            if !isDownloaded {
                Button("Save & Download Map") {
                    performSave()
                    startDownload()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save this trail to My Trips.")
        }
        .task { await loadElevation() }
        .onChange(of: offlineManager.packs) { _, packs in
            guard offlineState == .inProgress, let id = trackingPackId else { return }
            if packs.first(where: { $0.id == id })?.isComplete == true {
                offlineState = .done
            }
        }
    }

    @ViewBuilder
    private var trailMetadataRow: some View {
        let chips: [(icon: String, label: String, isWarning: Bool)] = [
            trail.visibilityLabel.map { ("eye", $0, trail.visibilityIsWarning) },
            trail.surfaceLabel.map { ("figure.walk", $0, false) },
            trail.isFeeRequired == true ? ("dollarsign.circle", "Fee required", true) : nil,
        ].compactMap { $0 }

        if !chips.isEmpty || trail.website != nil {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.label) { chip in
                        Label(chip.label, systemImage: chip.icon)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(chip.isWarning ? SaplingColors.accent : SaplingColors.bark)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                chip.isWarning
                                    ? SaplingColors.accent.opacity(0.1)
                                    : SaplingColors.parchment,
                                in: Capsule()
                            )
                    }
                    if let urlString = trail.website, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Label("More info", systemImage: "safari")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(SaplingColors.brand)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(SaplingColors.brand.opacity(0.08), in: Capsule())
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func performSave() {
        routeViewModel.saveTrailRoute(
            name: saveName.isEmpty ? trail.name : saveName,
            coordinates: trail.coordinates,
            distanceM: trail.distanceM,
            elevations: elevations
        )
        isSaved = true
    }

    private func startDownload() {
        if let id = offlineManager.downloadRegion(name: trail.name, coordinates: trail.coordinates) {
            offlineState = .inProgress
            trackingPackId = id
        }
    }

    private func loadElevation() async {
        guard elevations == nil else { return }
        if let prefetched = trail.elevationProfile {
            elevations = prefetched
            updateDefaultDays(from: prefetched)
            return
        }
        isLoadingElevation = true
        let fetched = try? await TrailSearchService.shared.fetchElevation(for: trail)
        elevations = fetched
        isLoadingElevation = false
        if let elevs = fetched { updateDefaultDays(from: elevs) }
    }

    private func updateDefaultDays(from elevs: [Double]) {
        let s = elevationStatsFromProfile(elevs)
        let gain = s.hasData ? s.gain : trail.elevationGainM
        numDays = max(2, (naismithMinutes(distanceM: trail.distanceM, elevationGainM: gain) + 479) / 480)
    }

    private func networkLabel(_ network: String) -> String {
        switch network {
        case "iwn": return "International Walking Network"
        case "nwn": return "National Walking Network"
        case "rwn": return "Regional Walking Network"
        case "lwn": return "Local Walking Network"
        default:    return network
        }
    }
}
