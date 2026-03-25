import CoreLocation
import Observation

@Observable
class LocationProvider {
    var currentLocation: CLLocation?
    var isAuthorized: Bool = false

    private var updateTask: Task<Void, Never>?

    func startUpdates() {
        updateTask = Task {
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    guard let location = update.location else { continue }
                    // Skip low-accuracy readings
                    guard location.horizontalAccuracy >= 0,
                          location.horizontalAccuracy <= 50 else { continue }
                    await MainActor.run {
                        self.currentLocation = location
                        self.isAuthorized = true
                    }
                }
            } catch {
                // Stream ended or was cancelled
                print("Location updates ended: \(error)")
            }
        }
    }

    func stopUpdates() {
        updateTask?.cancel()
        updateTask = nil
    }
}
