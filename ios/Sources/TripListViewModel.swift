import Observation

@Observable
class TripListViewModel {
    var trips: [FfiTripSummary] = []

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
        }
    }

    func deleteTrip(id: String) {
        do {
            try core.deleteTrip(id: id)
            trips.removeAll { $0.id == id }
        } catch {
            print("deleteTrip error: \(error)")
        }
    }

    func getTrackPoints(tripId: String) -> [FfiTrackPoint] {
        do {
            return try core.getTrackPoints(tripId: tripId)
        } catch {
            print("getTrackPoints error: \(error)")
            return []
        }
    }
}
