import CoreLocation
import Observation

@Observable
class RecordingViewModel {
    var isRecording: Bool = false
    var trackCoordinates: [CLLocationCoordinate2D] = []
    var distanceMeters: Double = 0
    var elevationGain: Double = 0
    var elapsedMs: Int64 = 0
    var pointCount: UInt32 = 0

    private let core: SaplingCore
    private let locationProvider = LocationProvider()
    private var recordingTask: Task<Void, Never>?
    private var currentTripId: String?

    /// Last known location from the provider, for centering the map.
    var currentLocation: CLLocation? {
        locationProvider.currentLocation
    }

    init(core: SaplingCore) {
        self.core = core
    }

    func startRecording(name: String? = nil) {
        do {
            let tripId = try core.startRecording(name: name)
            currentTripId = tripId
            isRecording = true
            trackCoordinates = []
            distanceMeters = 0
            elevationGain = 0
            elapsedMs = 0
            pointCount = 0

            locationProvider.startUpdates()

            recordingTask = Task {
                var lastTimestamp: TimeInterval = 0
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(100))
                    guard let location = locationProvider.currentLocation else { continue }
                    // Only process if we have a new location fix
                    let ts = location.timestamp.timeIntervalSince1970
                    guard ts > lastTimestamp else { continue }
                    lastTimestamp = ts

                    let point = FfiTrackPoint(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        // Pass nil when CoreLocation has no vertical fix (negative vAccuracy)
                        elevation: location.verticalAccuracy >= 0 ? location.altitude : nil,
                        hAccuracy: location.horizontalAccuracy,
                        vAccuracy: location.verticalAccuracy,
                        // Pass raw values — Rust handles negative (invalid) speed/course
                        speed: location.speed,
                        course: location.course,
                        timestampMs: Int64(ts * 1000),
                        baroRelativeAltitude: nil
                    )

                    do {
                        if let update = try core.addLocation(point: point) {
                            await MainActor.run {
                                self.trackCoordinates.append(location.coordinate)
                                self.distanceMeters = update.distanceM
                                self.elevationGain = update.elevationGain
                                self.elapsedMs = update.elapsedMs
                                self.pointCount = update.pointCount
                            }
                        }
                    } catch {
                        print("addLocation error: \(error)")
                    }
                }
            }
        } catch {
            print("startRecording error: \(error)")
        }
    }

    func stopRecording() {
        recordingTask?.cancel()
        recordingTask = nil
        locationProvider.stopUpdates()

        do {
            let _ = try core.stopRecording()
        } catch {
            print("stopRecording error: \(error)")
        }

        isRecording = false
        currentTripId = nil
    }
}
