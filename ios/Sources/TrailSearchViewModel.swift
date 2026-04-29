import CoreLocation
import Foundation

@Observable
class TrailSearchViewModel {
    var searchText: String = ""
    var results: [TrailResult] = []
    var recommendedTrails: [TrailResult] = []
    var isSearching: Bool = false
    var isLoadingRecommendations: Bool = false
    var searchError: String? = nil

    private let service = TrailSearchService.shared

    func search() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        isSearching = true
        searchError = nil
        Task { @MainActor in
            do {
                results = try await service.search(query: searchText)
            } catch {
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
