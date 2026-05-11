import CoreLocation
import SwiftUI

/// Root of the app. Owns the tab structure, all shared ViewModels, and any
/// state that needs to flow between tabs (e.g. displayRoute for "Start Navigation").
struct RootView: View {
    enum Tab: Hashable { case map, myTrips, explore, community }

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var selectedTab: Tab = .map
    @State private var viewModel: RecordingViewModel
    @State private var seedViewModel: SeedViewModel
    @State private var tripListViewModel: TripListViewModel
    @State private var routeViewModel: RouteBuilderViewModel
    @State private var displayRoute: [CLLocationCoordinate2D]? = nil
    @State private var activeRoute: FfiRoute? = nil
    @State private var initError: String? = nil

    init() {
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first!
        let dbPath = documentsDir.appendingPathComponent("sapling.db").path
        do {
            let core = try SaplingCore(dbPath: dbPath)
            _viewModel = State(initialValue: RecordingViewModel(core: core))
            _seedViewModel = State(initialValue: SeedViewModel(core: core))
            _tripListViewModel = State(initialValue: TripListViewModel(core: core))
            _routeViewModel = State(initialValue: RouteBuilderViewModel(core: core))
        } catch {
            let fallback = try! SaplingCore(dbPath: ":memory:")
            _viewModel = State(initialValue: RecordingViewModel(core: fallback))
            _seedViewModel = State(initialValue: SeedViewModel(core: fallback))
            _tripListViewModel = State(initialValue: TripListViewModel(core: fallback))
            _routeViewModel = State(initialValue: RouteBuilderViewModel(core: fallback))
            _initError = State(initialValue: "Failed to open database: \(error.localizedDescription)")
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView(
                viewModel: viewModel,
                seedViewModel: seedViewModel,
                tripListViewModel: tripListViewModel,
                routeViewModel: routeViewModel,
                displayRoute: $displayRoute,
                activeRoute: $activeRoute
            )
            .tabItem { Label("Map", systemImage: "map.fill") }
            .tag(Tab.map)

            ExploreView(
                seedViewModel: seedViewModel,
                routeViewModel: routeViewModel,
                onStartNavigation: { coords in
                    displayRoute = coords
                    selectedTab = .map
                }
            )
            .tabItem { Label("Explore", systemImage: "magnifyingglass") }
            .tag(Tab.explore)

            MyTripsView(
                tripListViewModel: tripListViewModel,
                routeViewModel: routeViewModel,
                seedViewModel: seedViewModel,
                onStartNavigation: { route in
                    activeRoute = route
                    displayRoute = route.waypoints.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    }
                    selectedTab = .map
                },
                onStartBuilding: {
                    routeViewModel.startBuilding()
                    selectedTab = .map
                }
            )
            .tabItem { Label("My Trips", systemImage: "figure.hiking") }
            .tag(Tab.myTrips)

            CommunityView()
                .tabItem { Label("Community", systemImage: "leaf.fill") }
                .tag(Tab.community)
        }
        .tint(SaplingColors.brand)
        .fontDesign(.rounded)
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { _ in }
        )) {
            OnboardingView()
        }
        .onChange(of: hasSeenOnboarding) { _, completed in
            if completed { selectedTab = .explore }
        }
        .alert("Database Error", isPresented: Binding(
            get: { initError != nil },
            set: { if !$0 { initError = nil } }
        )) {
            Button("OK") { initError = nil }
        } message: {
            Text(initError ?? "")
        }
    }
}
