import CoreLocation
import XCTest

@testable import Sapling

final class SeedViewModelTests: XCTestCase {
    private var core: SaplingCore!
    private var vm: SeedViewModel!

    override func setUpWithError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath = tempDir.appendingPathComponent(UUID().uuidString + ".db").path
        core = try SaplingCore(dbPath: dbPath)
        vm = SeedViewModel(core: core)
    }

    override func tearDown() {
        vm = nil
        core = nil
    }

    // MARK: - Initial State

    func testInitialStateSeedsEmpty() {
        XCTAssertTrue(vm.seeds.isEmpty, "seeds should be empty on fresh database")
    }

    func testInitialStateNoPendingState() {
        XCTAssertNil(vm.pendingSeedCoordinate)
        XCTAssertNil(vm.pendingSeedType)
        XCTAssertNil(vm.selectedSeed)
        XCTAssertFalse(vm.isShowingTypePicker)
        XCTAssertFalse(vm.isShowingQuickAdd)
        XCTAssertFalse(vm.isShowingDetail)
    }

    // MARK: - Start Seed Creation

    func testStartSeedCreationSetsPendingCoordinate() {
        let coord = CLLocationCoordinate2D(latitude: 40.0, longitude: -105.0)
        vm.startSeedCreation(at: coord)

        XCTAssertNotNil(vm.pendingSeedCoordinate)
        XCTAssertEqual(vm.pendingSeedCoordinate!.latitude, 40.0, accuracy: 0.001)
        XCTAssertEqual(vm.pendingSeedCoordinate!.longitude, -105.0, accuracy: 0.001)
    }

    func testStartSeedCreationShowsTypePicker() {
        let coord = CLLocationCoordinate2D(latitude: 40.0, longitude: -105.0)
        vm.startSeedCreation(at: coord)

        XCTAssertTrue(vm.isShowingTypePicker)
    }

    func testStartSeedCreationDoesNotShowQuickAdd() {
        let coord = CLLocationCoordinate2D(latitude: 40.0, longitude: -105.0)
        vm.startSeedCreation(at: coord)

        XCTAssertFalse(vm.isShowingQuickAdd)
    }

    // MARK: - Select Type

    func testSelectTypeSetsSeedType() {
        vm.selectType(.water)

        XCTAssertEqual(vm.pendingSeedType, .water)
    }

    func testSelectTypeHidesTypePicker() {
        let coord = CLLocationCoordinate2D(latitude: 40.0, longitude: -105.0)
        vm.startSeedCreation(at: coord)
        XCTAssertTrue(vm.isShowingTypePicker)

        vm.selectType(.water)

        XCTAssertFalse(vm.isShowingTypePicker)
    }

    func testSelectTypeShowsQuickAdd() {
        vm.selectType(.camp)

        XCTAssertTrue(vm.isShowingQuickAdd)
    }

    func testSelectTypeDifferentTypes() {
        for seedType: FfiSeedType in [.water, .camp, .beauty, .service, .custom] {
            vm.selectType(seedType)
            XCTAssertEqual(vm.pendingSeedType, seedType)
        }
    }

    // MARK: - Cancel Creation

    func testCancelCreationClearsPendingCoordinate() {
        let coord = CLLocationCoordinate2D(latitude: 40.0, longitude: -105.0)
        vm.startSeedCreation(at: coord)
        vm.selectType(.water)

        vm.cancelCreation()

        XCTAssertNil(vm.pendingSeedCoordinate)
    }

    func testCancelCreationClearsPendingType() {
        vm.selectType(.beauty)

        vm.cancelCreation()

        XCTAssertNil(vm.pendingSeedType)
    }

    func testCancelCreationHidesAllSheets() {
        let coord = CLLocationCoordinate2D(latitude: 40.0, longitude: -105.0)
        vm.startSeedCreation(at: coord)
        vm.selectType(.water)

        vm.cancelCreation()

        XCTAssertFalse(vm.isShowingTypePicker)
        XCTAssertFalse(vm.isShowingQuickAdd)
    }

    // MARK: - Save Seed

    func testSaveSeedAppendsToSeeds() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        vm.startSeedCreation(at: coord)
        vm.selectType(.water)

        vm.saveSeed(title: "Trail Spring", notes: "Fresh water source")

        XCTAssertEqual(vm.seeds.count, 1)
        XCTAssertEqual(vm.seeds.first?.title, "Trail Spring")
        XCTAssertEqual(vm.seeds.first?.seedType, .water)
        XCTAssertEqual(vm.seeds.first?.notes, "Fresh water source")
    }

    func testSaveSeedSetsCorrectCoordinates() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        vm.startSeedCreation(at: coord)
        vm.selectType(.camp)

        vm.saveSeed(title: "Campsite Alpha", notes: nil)

        XCTAssertEqual(vm.seeds.first?.latitude ?? 0, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(vm.seeds.first?.longitude ?? 0, -122.4194, accuracy: 0.0001)
    }

    func testSaveSeedClearsPendingState() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        vm.startSeedCreation(at: coord)
        vm.selectType(.water)

        vm.saveSeed(title: "Spring", notes: nil)

        XCTAssertNil(vm.pendingSeedCoordinate)
        XCTAssertNil(vm.pendingSeedType)
        XCTAssertFalse(vm.isShowingQuickAdd)
    }

    func testSaveSeedWithNilNotes() {
        let coord = CLLocationCoordinate2D(latitude: 40.0, longitude: -105.0)
        vm.startSeedCreation(at: coord)
        vm.selectType(.beauty)

        vm.saveSeed(title: "Sunset Point", notes: nil)

        XCTAssertEqual(vm.seeds.count, 1)
        XCTAssertNil(vm.seeds.first?.notes)
    }

    func testSaveSeedWithoutPendingStateIsNoOp() {
        vm.saveSeed(title: "Should Not Save", notes: nil)

        XCTAssertTrue(vm.seeds.isEmpty, "saveSeed should be a no-op without pending coordinate and type")
    }

    func testSaveMultipleSeeds() {
        let coords: [(Double, Double)] = [(37.0, -122.0), (38.0, -121.0), (39.0, -120.0)]
        let types: [FfiSeedType] = [.water, .camp, .beauty]
        let titles = ["Spring", "Camp", "Vista"]

        for i in 0..<3 {
            let coord = CLLocationCoordinate2D(latitude: coords[i].0, longitude: coords[i].1)
            vm.startSeedCreation(at: coord)
            vm.selectType(types[i])
            vm.saveSeed(title: titles[i], notes: nil)
        }

        XCTAssertEqual(vm.seeds.count, 3)
        XCTAssertEqual(vm.seeds[0].title, "Spring")
        XCTAssertEqual(vm.seeds[1].title, "Camp")
        XCTAssertEqual(vm.seeds[2].title, "Vista")
    }

    // MARK: - Select Existing Seed

    func testSelectSeedSetsSelectedSeed() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        vm.startSeedCreation(at: coord)
        vm.selectType(.service)
        vm.saveSeed(title: "Ranger Station", notes: nil)

        let seed = vm.seeds.first!
        vm.selectSeed(seed)

        XCTAssertEqual(vm.selectedSeed?.id, seed.id)
    }

    func testSelectSeedShowsDetail() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        vm.startSeedCreation(at: coord)
        vm.selectType(.service)
        vm.saveSeed(title: "Ranger Station", notes: nil)

        vm.selectSeed(vm.seeds.first!)

        XCTAssertTrue(vm.isShowingDetail)
    }

    // MARK: - Dismiss Detail

    func testDismissDetailClearsSelection() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        vm.startSeedCreation(at: coord)
        vm.selectType(.water)
        vm.saveSeed(title: "Creek", notes: nil)
        vm.selectSeed(vm.seeds.first!)

        vm.dismissDetail()

        XCTAssertNil(vm.selectedSeed)
    }

    func testDismissDetailHidesDetailSheet() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        vm.startSeedCreation(at: coord)
        vm.selectType(.water)
        vm.saveSeed(title: "Creek", notes: nil)
        vm.selectSeed(vm.seeds.first!)

        vm.dismissDetail()

        XCTAssertFalse(vm.isShowingDetail)
    }

    // MARK: - Load Seeds Persistence

    func testLoadSeedsReadsFromDatabase() throws {
        // Save a seed through the view model
        let coord = CLLocationCoordinate2D(latitude: 44.0, longitude: -110.0)
        vm.startSeedCreation(at: coord)
        vm.selectType(.custom)
        vm.saveSeed(title: "Persisted Seed", notes: "Should reload")

        XCTAssertEqual(vm.seeds.count, 1)

        // Create a fresh view model with the same core to verify DB persistence
        let vm2 = SeedViewModel(core: core)
        XCTAssertEqual(vm2.seeds.count, 1)
        XCTAssertEqual(vm2.seeds.first?.title, "Persisted Seed")
    }
}
