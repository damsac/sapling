import CoreLocation
import Foundation

@Observable
class TrailSearchViewModel {
    var results: [TrailResult] = []
    var recommendedTrails: [TrailResult] = []
    var isSearching: Bool = false
    var isLoadingRecommendations: Bool = false
    var searchError: String? = nil

    private let service = TrailSearchService.shared
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var elevationPrefetchTask: Task<Void, Never>?

    // Called on every keystroke — debounces before firing
    func scheduleSearch(query: String) {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchTask?.cancel()
            elevationPrefetchTask?.cancel()
            isSearching = false
            results = []
            searchError = nil
            return
        }
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            search(query: trimmed)
        }
    }

    func search(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        searchTask?.cancel()
        elevationPrefetchTask?.cancel()
        isSearching = true
        searchError = nil
        searchTask = Task { @MainActor in
            do {
                let r = try await service.search(query: trimmed)
                guard !Task.isCancelled else { return }
                results = r
                prefetchElevation(for: r)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                searchError = error.localizedDescription
            }
            isSearching = false
        }
    }

    func loadRecommendations(near center: CLLocationCoordinate2D) {
        isLoadingRecommendations = true
        Task { @MainActor in
            do {
                let r = try await service.nearbyTrails(center: center)
                recommendedTrails = r
                prefetchElevation(for: r)
            } catch {
                // silently fail for recommendations
            }
            isLoadingRecommendations = false
        }
    }

    func clearResults() {
        elevationPrefetchTask?.cancel()
        results = []
        searchError = nil
    }

    func fetchElevation(for trail: TrailResult) {
        Task { @MainActor in
            guard let elevations = try? await service.fetchElevation(for: trail) else { return }
            if let i = results.firstIndex(where: { $0.id == trail.id }) {
                results[i].elevationProfile = elevations
            }
            if let i = recommendedTrails.firstIndex(where: { $0.id == trail.id }) {
                recommendedTrails[i].elevationProfile = elevations
            }
        }
    }

    // Fetches elevation for the top 8 results serially so the difficulty badges
    // and gain stats in the list update without requiring the user to open each trail.
    private func prefetchElevation(for trails: [TrailResult]) {
        elevationPrefetchTask?.cancel()
        let top = Array(trails.prefix(8))
        elevationPrefetchTask = Task { @MainActor in
            for trail in top {
                guard !Task.isCancelled else { return }
                guard trail.elevationProfile == nil else { continue }
                guard let elevations = try? await service.fetchElevation(for: trail),
                      !Task.isCancelled else { continue }
                if let i = self.results.firstIndex(where: { $0.id == trail.id }) {
                    self.results[i].elevationProfile = elevations
                }
                if let i = self.recommendedTrails.firstIndex(where: { $0.id == trail.id }) {
                    self.recommendedTrails[i].elevationProfile = elevations
                }
            }
        }
    }
}
