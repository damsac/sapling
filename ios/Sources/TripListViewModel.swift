import Observation

@Observable
class TripListViewModel {
    var trips: [FfiTripSummary] = []
    var lastError: String? = nil

    private let core: SaplingCore

    init(core: SaplingCore) {
        self.core = core
        loadTrips()
    }

    func loadTrips() {
        do {
            trips = try core.listTrips()
        } catch {
            print("loadTrips error: \(error)")
            lastError = error.localizedDescription
        }
    }

    func deleteTrip(id: String) {
        do {
            try core.deleteTrip(id: id)
            trips.removeAll { $0.id == id }
        } catch {
            print("deleteTrip error: \(error)")
            lastError = error.localizedDescription
        }
    }

    func getTrackPoints(tripId: String) -> [FfiTrackPoint] {
        do {
            return try core.getTrackPoints(tripId: tripId)
        } catch {
            print("getTrackPoints error: \(error)")
            lastError = error.localizedDescription
            return []
        }
    }
}
