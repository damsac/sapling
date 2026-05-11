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

    // Called on every keystroke — debounces before firing
    func scheduleSearch(query: String) {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchTask?.cancel()
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
        isSearching = true
        searchError = nil
        searchTask = Task { @MainActor in
            do {
                let r = try await service.search(query: trimmed)
                guard !Task.isCancelled else { return }
                results = r
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
                recommendedTrails = try await service.nearbyTrails(center: center)
            } catch {
                // silently fail for recommendations
            }
            isLoadingRecommendations = false
        }
    }

    func clearResults() {
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
}
