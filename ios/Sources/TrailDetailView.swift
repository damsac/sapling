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

    private var stats: RouteElevationStats {
        elevations.map { elevationStatsFromProfile($0) }
            ?? RouteElevationStats(gain: 0, loss: 0, minElev: 0, maxElev: 0, hasData: false)
    }
    private var gainM: Double { stats.hasData ? stats.gain : trail.elevationGainM }
    private var estimatedMinutes: Int { naismithMinutes(distanceM: trail.distanceM, elevationGainM: gainM) }
    private var difficulty: RouteDifficulty { routeDifficulty(distanceM: trail.distanceM, gainM: gainM) }
    private var nearbySeeds: [SeedOnRoute] { seedsNearRoute(seedViewModel.seeds, coordinates: trail.coordinates) }
    private var isMultiDay: Bool { estimatedMinutes > 300 }
    private var campRecommendations: [CampRecommendation] {
        guard !isLoadingElevation else { return [] }
        let campSeeds = nearbySeeds.filter { $0.seed.seedType == .camp }
        guard campSeeds.isEmpty else { return [] }
        return computeCampRecommendations(
            coordinates: trail.coordinates,
            elevations: elevations,
            totalDistanceM: trail.distanceM,
            estimatedMinutes: estimatedMinutes
        )
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
                    }

                    if isMultiDay {
                        DayBreakdownSection(
                            campSeeds: nearbySeeds.filter { $0.seed.seedType == .camp },
                            recommendations: campRecommendations,
                            totalDistanceM: trail.distanceM,
                            estimatedMinutes: estimatedMinutes
                        )
                    }

                    Button {
                        onStartNavigation(trail.coordinates)
                    } label: {
                        Label("Start Navigation", systemImage: "location.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(SaplingColors.brand, in: RoundedRectangle(cornerRadius: 14))
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    saveName = trail.name
                    showSaveAlert = true
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isSaved ? SaplingColors.brand : SaplingColors.ink)
                }
            }
        }
        .alert("Save Trail", isPresented: $showSaveAlert) {
            TextField("Route name", text: $saveName)
            Button("Save") {
                routeViewModel.saveTrailRoute(
                    name: saveName.isEmpty ? trail.name : saveName,
                    coordinates: trail.coordinates,
                    distanceM: trail.distanceM,
                    elevations: elevations
                )
                isSaved = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save this trail to My Trips.")
        }
        .task { await loadElevation() }
    }

    private func loadElevation() async {
        guard elevations == nil else { return }
        isLoadingElevation = true
        elevations = try? await TrailSearchService.shared.fetchElevation(for: trail)
        isLoadingElevation = false
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
