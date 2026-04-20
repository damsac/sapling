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

    func getSeedsForTrip(tripId: String) -> [FfiSeed] {
        do {
            return try core.getSeedsForTrip(tripId: tripId)
        } catch {
            print("getSeedsForTrip error: \(error)")
            lastError = error.localizedDescription
            return []
        }
    }

    func renameTrip(id: String, name: String) {
        do {
            try core.renameTrip(id: id, name: name)
            if let idx = trips.firstIndex(where: { $0.id == id }) {
                let t = trips[idx]
                trips[idx] = FfiTripSummary(
                    id: t.id, name: name, notes: t.notes,
                    distanceM: t.distanceM, elevationGain: t.elevationGain,
                    elevationLoss: t.elevationLoss, durationMs: t.durationMs,
                    seedCount: t.seedCount, segmentCount: t.segmentCount,
                    createdAt: t.createdAt
                )
            }
        } catch {
            print("renameTrip error: \(error)")
            lastError = error.localizedDescription
        }
    }

    func updateTripNotes(id: String, notes: String?) {
        do {
            try core.updateTripNotes(id: id, notes: notes)
            if let idx = trips.firstIndex(where: { $0.id == id }) {
                let t = trips[idx]
                trips[idx] = FfiTripSummary(
                    id: t.id, name: t.name, notes: notes,
                    distanceM: t.distanceM, elevationGain: t.elevationGain,
                    elevationLoss: t.elevationLoss, durationMs: t.durationMs,
                    seedCount: t.seedCount, segmentCount: t.segmentCount,
                    createdAt: t.createdAt
                )
            }
        } catch {
            print("updateTripNotes error: \(error)")
            lastError = error.localizedDescription
        }
    }

    func importGpx(fileURL: URL, name: String?) -> FfiTripSummary? {
        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }
        do {
            let trip = try core.importTripFromGpx(filePath: fileURL.path, name: name)
            trips.insert(trip, at: 0)
            return trip
        } catch {
            print("importGpx error: \(error)")
            lastError = error.localizedDescription
            return nil
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
