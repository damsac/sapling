import CoreLocation
import SwiftUI

struct ExploreView: View {
    var seedViewModel: SeedViewModel
    var routeViewModel: RouteBuilderViewModel
    let onStartNavigation: ([CLLocationCoordinate2D]) -> Void

    @State private var searchVM = TrailSearchViewModel()
    @State private var searchText = ""
    @State private var expandedCategories: Set<TrailCategory> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    searchBar
                    if searchVM.isSearching {
                        searchingState
                    } else if let error = searchVM.searchError {
                        errorCard(error)
                    } else if !searchVM.results.isEmpty {
                        resultsList
                    } else if searchText.isEmpty {
                        discoveryStubs
                    } else {
                        emptyResults
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(SaplingColors.stone.ignoresSafeArea())
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await loadNearbyIfAuthorized() }
    }

    private func loadNearbyIfAuthorized() async {
        guard searchVM.recommendedTrails.isEmpty && !searchVM.isLoadingRecommendations else { return }
        let status = LocationProvider.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                guard let loc = update.location,
                      loc.horizontalAccuracy >= 0,
                      loc.horizontalAccuracy < 200
                else { continue }
                searchVM.loadRecommendations(near: loc.coordinate)
                break
            }
        } catch {}
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SaplingColors.bark)
            TextField("Search trails, parks, peaks…", text: $searchText)
                .font(.subheadline)
                .foregroundStyle(SaplingColors.ink)
                .autocorrectionDisabled()
                .onChange(of: searchText) { _, newVal in searchVM.scheduleSearch(query: newVal) }
                .onSubmit { searchVM.search(query: searchText) }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchVM.clearResults()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(SaplingColors.bark.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SaplingColors.bark.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - States

    private var searchingState: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Searching trails…")
                .font(.subheadline)
                .foregroundStyle(SaplingColors.bark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 14))
    }

    private var emptyResults: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(SaplingColors.bark.opacity(0.4))
            VStack(alignment: .leading, spacing: 3) {
                Text("No trails found")
                    .font(.subheadline)
                    .foregroundStyle(SaplingColors.bark)
                Text("Try a different location or trail name.")
                    .font(.caption2)
                    .foregroundStyle(SaplingColors.bark.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 14))
    }

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(SaplingColors.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Search failed")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(SaplingColors.ink)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(SaplingColors.bark)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Results List

    private var resultsList: some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            Text("\(searchVM.results.count) TRAIL\(searchVM.results.count == 1 ? "" : "S") FOUND")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SaplingColors.bark)
                .kerning(0.8)

            ForEach(TrailCategory.allCases, id: \.self) { category in
                let group = searchVM.results.filter { $0.category == category }
                if !group.isEmpty {
                    categorySection(category, trails: group)
                }
            }
        }
    }

    private func categorySection(_ category: TrailCategory, trails: [TrailResult]) -> some View {
        let isExpanded = expandedCategories.contains(category)
        let visible = isExpanded ? trails : Array(trails.prefix(10))
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SaplingColors.brand)
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.rawValue.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SaplingColors.bark)
                        .kerning(0.8)
                    Text(category.subtitle)
                        .font(.caption2)
                        .foregroundStyle(SaplingColors.bark.opacity(0.6))
                }
            }

            ForEach(visible) { trail in
                NavigationLink {
                    TrailDetailView(
                        trail: trail,
                        seedViewModel: seedViewModel,
                        routeViewModel: routeViewModel,
                        onStartNavigation: onStartNavigation
                    )
                } label: {
                    TrailResultRow(trail: trail)
                }
                .buttonStyle(.plain)
            }

            if trails.count > 10 {
                Button {
                    if isExpanded {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                } label: {
                    Text(isExpanded ? "Show less" : "View \(trails.count - 10) more…")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SaplingColors.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Discovery

    private var discoveryStubs: some View {
        VStack(alignment: .leading, spacing: 24) {
            nearYouSection
            comingSoonSection(
                "TRENDING",
                icon: "chart.line.uptrend.xyaxis",
                message: "Popular routes from the Sapling community.",
                hint: "Coming in Phase 3"
            )
            comingSoonSection(
                "CURATED LISTS",
                icon: "list.star",
                message: "Best wildflower trails, peak-baggers, and more.",
                hint: "Coming in Phase 3"
            )
        }
    }

    private var nearYouSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SaplingColors.brand)
                VStack(alignment: .leading, spacing: 1) {
                    Text("NEAR YOU")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SaplingColors.bark)
                        .kerning(0.8)
                    Text("Trails within 40 km")
                        .font(.caption2)
                        .foregroundStyle(SaplingColors.bark.opacity(0.6))
                }
            }

            if searchVM.isLoadingRecommendations {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Finding trails near you…")
                        .font(.subheadline)
                        .foregroundStyle(SaplingColors.bark)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 14))
            } else if searchVM.recommendedTrails.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(SaplingColors.bark.opacity(0.35))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Search to explore")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(SaplingColors.ink)
                        Text("Type a trail name or place above to get started.")
                            .font(.caption2)
                            .foregroundStyle(SaplingColors.bark.opacity(0.55))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 14))
            } else {
                ForEach(TrailCategory.allCases, id: \.self) { category in
                    let group = searchVM.recommendedTrails.filter { $0.category == category }
                    if !group.isEmpty {
                        categorySection(category, trails: group)
                    }
                }
            }
        }
    }

    private func comingSoonSection(_ title: String, icon: String, message: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SaplingColors.bark)
                .kerning(0.8)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(SaplingColors.brand.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(SaplingColors.brand)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(SaplingColors.ink)
                    Text(hint)
                        .font(.caption2)
                        .foregroundStyle(SaplingColors.bark)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Trail Result Row

private struct TrailResultRow: View {
    let trail: TrailResult

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(SaplingColors.brand.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "figure.hiking")
                    .font(.body)
                    .foregroundStyle(SaplingColors.brand)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(trail.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SaplingColors.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(formatDistance(trail.distanceM))
                    if trail.elevationGainM > 0 {
                        Text("·")
                        Text("+\(formatElevation(trail.elevationGainM))")
                    }
                }
                .font(.caption2)
                .foregroundStyle(SaplingColors.bark)
            }

            Spacer()

            if let label = trail.difficultyLabel {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(difficultyColor(label), in: Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SaplingColors.bark.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 14))
    }

    private func difficultyColor(_ label: String) -> Color {
        switch label {
        case "Easy":     return .green
        case "Moderate": return Color(hue: 0.13, saturation: 0.8, brightness: 0.85)
        case "Hard":     return .orange
        default:         return .red
        }
    }
}
