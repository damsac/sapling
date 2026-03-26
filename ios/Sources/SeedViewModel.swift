import CoreLocation
import Observation

@Observable
class SeedViewModel {
    var seeds: [FfiSeed] = []
    var selectedSeed: FfiSeed? = nil
    var isShowingTypePicker: Bool = false
    var isShowingQuickAdd: Bool = false
    var isShowingDetail: Bool = false
    var pendingSeedCoordinate: CLLocationCoordinate2D? = nil
    var pendingSeedType: FfiSeedType? = nil

    private let core: SaplingCore

    init(core: SaplingCore) {
        self.core = core
        loadSeeds()
    }

    func loadSeeds() {
        do {
            seeds = try core.listSeeds()
        } catch {
            print("loadSeeds error: \(error)")
        }
    }

    func startSeedCreation(at coordinate: CLLocationCoordinate2D) {
        pendingSeedCoordinate = coordinate
        isShowingTypePicker = true
    }

    func selectType(_ type: FfiSeedType) {
        pendingSeedType = type
        isShowingTypePicker = false
        isShowingQuickAdd = true
    }

    func cancelCreation() {
        pendingSeedCoordinate = nil
        pendingSeedType = nil
        isShowingTypePicker = false
        isShowingQuickAdd = false
    }

    func saveSeed(title: String, notes: String?) {
        guard let coord = pendingSeedCoordinate, let type = pendingSeedType else { return }
        do {
            let input = FfiCreateSeedInput(
                seedType: type,
                title: title,
                notes: notes,
                latitude: coord.latitude,
                longitude: coord.longitude,
                elevation: nil,
                confidence: 75,
                tags: []
            )
            let seed = try core.createSeed(input: input)
            seeds.append(seed)
            isShowingQuickAdd = false
            pendingSeedCoordinate = nil
            pendingSeedType = nil
        } catch {
            print("createSeed error: \(error)")
        }
    }

    func selectSeed(_ seed: FfiSeed) {
        selectedSeed = seed
        isShowingDetail = true
    }

    func dismissDetail() {
        selectedSeed = nil
        isShowingDetail = false
    }
}
