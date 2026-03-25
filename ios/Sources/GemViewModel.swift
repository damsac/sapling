import CoreLocation
import Observation

@Observable
class GemViewModel {
    var gems: [FfiGem] = []
    var selectedGem: FfiGem? = nil
    var isShowingTypePicker: Bool = false
    var isShowingQuickAdd: Bool = false
    var isShowingDetail: Bool = false
    var pendingGemCoordinate: CLLocationCoordinate2D? = nil
    var pendingGemType: FfiGemType? = nil

    private let core: SaplingCore

    init(core: SaplingCore) {
        self.core = core
        loadGems()
    }

    func loadGems() {
        do {
            gems = try core.listGems()
        } catch {
            print("loadGems error: \(error)")
        }
    }

    func startGemCreation(at coordinate: CLLocationCoordinate2D) {
        pendingGemCoordinate = coordinate
        isShowingTypePicker = true
    }

    func selectType(_ type: FfiGemType) {
        pendingGemType = type
        isShowingTypePicker = false
        isShowingQuickAdd = true
    }

    func cancelCreation() {
        pendingGemCoordinate = nil
        pendingGemType = nil
        isShowingTypePicker = false
        isShowingQuickAdd = false
    }

    func saveGem(title: String, notes: String?) {
        guard let coord = pendingGemCoordinate, let type = pendingGemType else { return }
        do {
            let input = FfiCreateGemInput(
                gemType: type,
                title: title,
                notes: notes,
                latitude: coord.latitude,
                longitude: coord.longitude,
                elevation: nil,
                confidence: 75,
                tags: []
            )
            let gem = try core.createGem(input: input)
            gems.append(gem)
            isShowingQuickAdd = false
            pendingGemCoordinate = nil
            pendingGemType = nil
        } catch {
            print("createGem error: \(error)")
        }
    }

    func selectGem(_ gem: FfiGem) {
        selectedGem = gem
        isShowingDetail = true
    }

    func dismissDetail() {
        selectedGem = nil
        isShowingDetail = false
    }
}
