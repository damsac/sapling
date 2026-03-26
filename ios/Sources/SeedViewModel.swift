import CoreLocation
import Observation

/// Represents a seed that has been dropped on the map but not yet persisted.
struct PendingSeed: Equatable {
    var type: FfiSeedType
    var coordinate: CLLocationCoordinate2D
    var createdAt: Date = Date()

    static func == (lhs: PendingSeed, rhs: PendingSeed) -> Bool {
        lhs.type == rhs.type
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.createdAt == rhs.createdAt
    }
}

@Observable
class SeedViewModel {
    var seeds: [FfiSeed] = []
    var selectedSeed: FfiSeed? = nil
    var isShowingTypePicker: Bool = false
    var isShowingQuickAdd: Bool = false
    var isShowingDetail: Bool = false
    var pendingSeedCoordinate: CLLocationCoordinate2D? = nil
    var pendingSeedType: FfiSeedType? = nil

    /// The seed that's been quick-dropped but not yet saved.
    var pendingSeed: PendingSeed? = nil

    private let core: SaplingCore
    private var autoSaveTask: Task<Void, Never>?

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

    // MARK: - Quick Drop Flow

    /// Drop a seed at the given location. It enters "pending" state and auto-saves after 3 seconds.
    func quickDropSeed(type: FfiSeedType, at coordinate: CLLocationCoordinate2D) {
        // Cancel any existing pending seed
        cancelPendingSeed()

        pendingSeed = PendingSeed(type: type, coordinate: coordinate)
        startAutoSaveTimer()
    }

    /// Update the pending seed's position (called during drag).
    func updatePendingSeedPosition(_ coordinate: CLLocationCoordinate2D) {
        guard pendingSeed != nil else { return }
        pendingSeed?.coordinate = coordinate
        // Restart auto-save timer on drag
        startAutoSaveTimer()
    }

    /// Confirm and persist the pending seed.
    func confirmPendingSeed() {
        guard let pending = pendingSeed else { return }
        autoSaveTask?.cancel()
        autoSaveTask = nil

        do {
            let input = FfiCreateSeedInput(
                seedType: pending.type,
                title: pending.type.defaultTitle,
                notes: nil,
                latitude: pending.coordinate.latitude,
                longitude: pending.coordinate.longitude,
                elevation: nil,
                confidence: 75,
                tags: []
            )
            let seed = try core.createSeed(input: input)
            seeds.append(seed)
            pendingSeed = nil
        } catch {
            print("confirmPendingSeed error: \(error)")
        }
    }

    /// Remove the pending seed without saving.
    func cancelPendingSeed() {
        autoSaveTask?.cancel()
        autoSaveTask = nil
        pendingSeed = nil
    }

    // MARK: - Auto-Save Timer

    private func startAutoSaveTimer() {
        autoSaveTask?.cancel()
        autoSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.confirmPendingSeed()
        }
    }

    // MARK: - Long-Press Creation Flow (unchanged)

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

    // MARK: - Detail

    func selectSeed(_ seed: FfiSeed) {
        selectedSeed = seed
        isShowingDetail = true
    }

    func dismissDetail() {
        selectedSeed = nil
        isShowingDetail = false
    }
}
