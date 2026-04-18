import CoreLocation
import Observation

@Observable
class LocationProvider {
    var currentLocation: CLLocation?
    var isAuthorized: Bool = false

    private var updateTask: Task<Void, Never>?
    private var backgroundSession: CLBackgroundActivitySession?

    /// Current authorization status without triggering a permission prompt.
    static var authorizationStatus: CLAuthorizationStatus {
        CLLocationManager().authorizationStatus
    }

    func startUpdates() {
        // Create a background activity session so iOS keeps delivering
        // location updates when the app is backgrounded
        backgroundSession = CLBackgroundActivitySession()

        updateTask = Task {
            do {
                // .fitness preset keeps updates flowing while stationary.
                // Default preset suppresses updates to save battery, which
                // delays the first fix until motion is detected.
                for try await update in CLLocationUpdate.liveUpdates(.fitness) {
                    guard let location = update.location else { continue }
                    // Skip invalid readings (negative means CoreLocation has no fix)
                    guard location.horizontalAccuracy >= 0 else { continue }
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
        backgroundSession?.invalidate()
        backgroundSession = nil
    }
}
