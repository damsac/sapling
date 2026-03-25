import CoreLocation
import XCTest

@testable import Sapling

final class GemViewModelTests: XCTestCase {
    private var core: SaplingCore!
    private var vm: GemViewModel!

    override func setUpWithError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath = tempDir.appendingPathComponent(UUID().uuidString + ".db").path
        core = try SaplingCore(dbPath: dbPath)
        vm = GemViewModel(core: core)
    }

    override func tearDown() {
        vm = nil
        core = nil
    }

    // MARK: - Initial State

    func testInitialStateGemsEmpty() {
        XCTAssertTrue(vm.gems.isEmpty, "gems should be empty on fresh database")
    }

    func testInitialStateNoPendingState() {
        XCTAssertNil(vm.pendingGemCoordinate)
        XCTAssertNil(vm.pendingGemType)
        XCTAssertNil(vm.selectedGem)
        XCTAssertFalse(vm.isShowingTypePicker)
        XCTAssertFalse(vm.isShowingQuickAdd)
        XCTAssertFalse(vm.isShowingDetail)
    }

    // MARK: - Start Gem Creation

    func testStartGemCreationSetsPendingCoordinate() {
        let coord = CLLocationCoordinate2D(latitude: 40.0, longitude: -105.0)
        vm.startGemCreation(at: coord)

        XCTAssertNotNil(vm.pendingGemCoordinate)
        XCTAssertEqual(vm.pendingGemCoordinate!.latitude, 40.0, accuracy: 0.001)
        XCTAssertEqual(vm.pendingGemCoordinate!.longitude, -105.0, accuracy: 0.001)
    }

    func testStartGemCreationShowsTypePicker() {
        let coord = CLLocationCoordinate2D(latitude: 40.0, longitude: -105.0)
        vm.startGemCreation(at: coord)

        XCTAssertTrue(vm.isShowingTypePicker)
    }

    func testStartGemCreationDoesNotShowQuickAdd() {
        let coord = CLLocationCoordinate2D(latitude: 40.0, longitude: -105.0)
        vm.startGemCreation(at: coord)

        XCTAssertFalse(vm.isShowingQuickAdd)
    }

    // MARK: - Select Type

    func testSelectTypeSetsGemType() {
        vm.selectType(.water)

        XCTAssertEqual(vm.pendingGemType, .water)
    }

    func testSelectTypeHidesTypePicker() {
        let coord = CLLocationCoordinate2D(latitude: 40.0, longitude: -105.0)
        vm.startGemCreation(at: coord)
        XCTAssertTrue(vm.isShowingTypePicker)

        vm.selectType(.water)

        XCTAssertFalse(vm.isShowingTypePicker)
    }

    func testSelectTypeShowsQuickAdd() {
        vm.selectType(.camp)

        XCTAssertTrue(vm.isShowingQuickAdd)
    }

    func testSelectTypeDifferentTypes() {
        for gemType: FfiGemType in [.water, .camp, .beauty, .service, .custom] {
            vm.selectType(gemType)
            XCTAssertEqual(vm.pendingGemType, gemType)
        }
    }

    // MARK: - Cancel Creation

    func testCancelCreationClearsPendingCoordinate() {
        let coord = CLLocationCoordinate2D(latitude: 40.0, longitude: -105.0)
        vm.startGemCreation(at: coord)
        vm.selectType(.water)

        vm.cancelCreation()

        XCTAssertNil(vm.pendingGemCoordinate)
    }

    func testCancelCreationClearsPendingType() {
        vm.selectType(.beauty)

        vm.cancelCreation()

        XCTAssertNil(vm.pendingGemType)
    }

    func testCancelCreationHidesAllSheets() {
        let coord = CLLocationCoordinate2D(latitude: 40.0, longitude: -105.0)
        vm.startGemCreation(at: coord)
        vm.selectType(.water)

        vm.cancelCreation()

        XCTAssertFalse(vm.isShowingTypePicker)
        XCTAssertFalse(vm.isShowingQuickAdd)
    }

    // MARK: - Save Gem

    func testSaveGemAppendsToGems() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        vm.startGemCreation(at: coord)
        vm.selectType(.water)

        vm.saveGem(title: "Trail Spring", notes: "Fresh water source")

        XCTAssertEqual(vm.gems.count, 1)
        XCTAssertEqual(vm.gems.first?.title, "Trail Spring")
        XCTAssertEqual(vm.gems.first?.gemType, .water)
        XCTAssertEqual(vm.gems.first?.notes, "Fresh water source")
    }

    func testSaveGemSetsCorrectCoordinates() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        vm.startGemCreation(at: coord)
        vm.selectType(.camp)

        vm.saveGem(title: "Campsite Alpha", notes: nil)

        XCTAssertEqual(vm.gems.first?.latitude ?? 0, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(vm.gems.first?.longitude ?? 0, -122.4194, accuracy: 0.0001)
    }

    func testSaveGemClearsPendingState() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        vm.startGemCreation(at: coord)
        vm.selectType(.water)

        vm.saveGem(title: "Spring", notes: nil)

        XCTAssertNil(vm.pendingGemCoordinate)
        XCTAssertNil(vm.pendingGemType)
        XCTAssertFalse(vm.isShowingQuickAdd)
    }

    func testSaveGemWithNilNotes() {
        let coord = CLLocationCoordinate2D(latitude: 40.0, longitude: -105.0)
        vm.startGemCreation(at: coord)
        vm.selectType(.beauty)

        vm.saveGem(title: "Sunset Point", notes: nil)

        XCTAssertEqual(vm.gems.count, 1)
        XCTAssertNil(vm.gems.first?.notes)
    }

    func testSaveGemWithoutPendingStateIsNoOp() {
        vm.saveGem(title: "Should Not Save", notes: nil)

        XCTAssertTrue(vm.gems.isEmpty, "saveGem should be a no-op without pending coordinate and type")
    }

    func testSaveMultipleGems() {
        let coords: [(Double, Double)] = [(37.0, -122.0), (38.0, -121.0), (39.0, -120.0)]
        let types: [FfiGemType] = [.water, .camp, .beauty]
        let titles = ["Spring", "Camp", "Vista"]

        for i in 0..<3 {
            let coord = CLLocationCoordinate2D(latitude: coords[i].0, longitude: coords[i].1)
            vm.startGemCreation(at: coord)
            vm.selectType(types[i])
            vm.saveGem(title: titles[i], notes: nil)
        }

        XCTAssertEqual(vm.gems.count, 3)
        XCTAssertEqual(vm.gems[0].title, "Spring")
        XCTAssertEqual(vm.gems[1].title, "Camp")
        XCTAssertEqual(vm.gems[2].title, "Vista")
    }

    // MARK: - Select Existing Gem

    func testSelectGemSetsSelectedGem() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        vm.startGemCreation(at: coord)
        vm.selectType(.service)
        vm.saveGem(title: "Ranger Station", notes: nil)

        let gem = vm.gems.first!
        vm.selectGem(gem)

        XCTAssertEqual(vm.selectedGem?.id, gem.id)
    }

    func testSelectGemShowsDetail() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        vm.startGemCreation(at: coord)
        vm.selectType(.service)
        vm.saveGem(title: "Ranger Station", notes: nil)

        vm.selectGem(vm.gems.first!)

        XCTAssertTrue(vm.isShowingDetail)
    }

    // MARK: - Dismiss Detail

    func testDismissDetailClearsSelection() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        vm.startGemCreation(at: coord)
        vm.selectType(.water)
        vm.saveGem(title: "Creek", notes: nil)
        vm.selectGem(vm.gems.first!)

        vm.dismissDetail()

        XCTAssertNil(vm.selectedGem)
    }

    func testDismissDetailHidesDetailSheet() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        vm.startGemCreation(at: coord)
        vm.selectType(.water)
        vm.saveGem(title: "Creek", notes: nil)
        vm.selectGem(vm.gems.first!)

        vm.dismissDetail()

        XCTAssertFalse(vm.isShowingDetail)
    }

    // MARK: - Load Gems Persistence

    func testLoadGemsReadsFromDatabase() throws {
        // Save a gem through the view model
        let coord = CLLocationCoordinate2D(latitude: 44.0, longitude: -110.0)
        vm.startGemCreation(at: coord)
        vm.selectType(.custom)
        vm.saveGem(title: "Persisted Gem", notes: "Should reload")

        XCTAssertEqual(vm.gems.count, 1)

        // Create a fresh view model with the same core to verify DB persistence
        let vm2 = GemViewModel(core: core)
        XCTAssertEqual(vm2.gems.count, 1)
        XCTAssertEqual(vm2.gems.first?.title, "Persisted Gem")
    }
}
