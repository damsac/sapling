import CoreLocation
import SwiftUI

struct ExploreView: View {
    var seedViewModel: SeedViewModel
    var routeViewModel: RouteBuilderViewModel
    let onStartNavigation: ([CLLocationCoordinate2D]) -> Void

    @State private var searchVM = TrailSearchViewModel()
    @State private var searchText = ""
    @State private var categoryLimits: [TrailCategory: Int] = [:]
    @State private var distanceFilter: DistanceFilter = .any
    @State private var difficultyFilter: DifficultyFilter = .any

    private var hasActiveFilters: Bool {
        distanceFilter != .any || difficultyFilter != .any
    }

    private func applyFilters(_ trails: [TrailResult]) -> [TrailResult] {
        trails.filter { distanceFilter.matches($0) && difficultyFilter.matches($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    searchBar
                    if !searchVM.results.isEmpty || !searchVM.recommendedTrails.isEmpty {
                        filterBar
                    }
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

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DistanceFilter.allCases, id: \.self) { f in
                    filterChip(f.rawValue, active: distanceFilter == f) {
                        distanceFilter = distanceFilter == f ? .any : f
                        categoryLimits = [:]
                    }
                }
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 2)
                ForEach(DifficultyFilter.allCases.dropFirst(), id: \.self) { f in
                    filterChip(f.rawValue, active: difficultyFilter == f) {
                        difficultyFilter = difficultyFilter == f ? .any : f
                        categoryLimits = [:]
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func filterChip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(active ? .white : SaplingColors.bark)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(active ? SaplingColors.brand : SaplingColors.parchment, in: Capsule())
                .overlay(Capsule().stroke(active ? Color.clear : SaplingColors.bark.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Results List

    private var resultsList: some View {
        let filtered = applyFilters(searchVM.results)
        return LazyVStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("\(filtered.count) TRAIL\(filtered.count == 1 ? "" : "S") FOUND")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SaplingColors.bark)
                    .kerning(0.8)
                if hasActiveFilters {
                    Spacer()
                    Button("Clear") {
                        distanceFilter = .any
                        difficultyFilter = .any
                        categoryLimits = [:]
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SaplingColors.brand)
                }
            }

            if filtered.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundStyle(SaplingColors.bark.opacity(0.4))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No trails match your filters")
                            .font(.subheadline)
                            .foregroundStyle(SaplingColors.bark)
                        Text("Try adjusting or clearing the filters above.")
                            .font(.caption2)
                            .foregroundStyle(SaplingColors.bark.opacity(0.55))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 14))
            } else {
                ForEach(TrailCategory.allCases, id: \.self) { category in
                    let group = filtered.filter { $0.category == category }
                    if !group.isEmpty {
                        categorySection(category, trails: group)
                    }
                }
            }
        }
    }

    private func categorySection(_ category: TrailCategory, trails: [TrailResult]) -> some View {
        let limit = categoryLimits[category] ?? 5
        let visible = Array(trails.prefix(limit))
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

            if trails.count > limit {
                Button {
                    categoryLimits[category] = limit + 5
                } label: {
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
                let filtered = applyFilters(searchVM.recommendedTrails)
                if filtered.isEmpty && hasActiveFilters {
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title2)
                            .foregroundStyle(SaplingColors.bark.opacity(0.4))
                        Text("No nearby trails match your filters.")
                            .font(.subheadline)
                            .foregroundStyle(SaplingColors.bark)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 14))
                } else {
                    ForEach(TrailCategory.allCases, id: \.self) { category in
                        let group = filtered.filter { $0.category == category }
                        if !group.isEmpty {
                            categorySection(category, trails: group)
                        }
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

// MARK: - Filter Types

enum DistanceFilter: String, CaseIterable {
    case any      = "Any Distance"
    case short    = "< 8 km"
    case day      = "8–20 km"
    case longDay  = "20–35 km"
    case overnight = "35 km+"

    func matches(_ trail: TrailResult) -> Bool {
        switch self {
        case .any:      return true
        case .short:    return trail.category == .shortWalk
        case .day:      return trail.category == .dayHike
        case .longDay:  return trail.category == .longDay
        case .overnight: return trail.category == .overnight
        }
    }
}

enum DifficultyFilter: String, CaseIterable {
    case any      = "Any"
    case easy     = "Easy"
    case moderate = "Moderate"
    case hard     = "Hard"
    case epic     = "Epic"

    func matches(_ trail: TrailResult) -> Bool {
        switch self {
        case .any:      return true
        case .easy:     return trail.difficultyLabel == "Easy"
        case .moderate: return trail.difficultyLabel == "Moderate"
        case .hard:     return trail.difficultyLabel == "Hard"
        case .epic:     return trail.difficultyLabel == "Epic"
        }
    }
}
