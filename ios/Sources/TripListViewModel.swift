import Foundation
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

    func exportGpx(trip: FfiTripSummary) -> URL? {
        do {
            let gpxString = try core.exportTripGpx(tripId: trip.id)
            let safeName = trip.name.replacingOccurrences(of: "/", with: "-")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).gpx")
            try gpxString.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("exportGpx error: \(error)")
            lastError = error.localizedDescription
            return nil
        }
    }
}
