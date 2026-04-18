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
    var lastError: String? = nil

    /// Set after recording stops; drives the trip summary sheet.
    var lastTripSummary: FfiTripSummary? = nil
    /// Track coordinates from the completed trip, preserved for the summary map.
    var lastTripTrack: [CLLocationCoordinate2D] = []

    private let core: SaplingCore
    private let locationProvider = LocationProvider()
    private var recordingTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var recordingStartedAt: Date?
    private var currentTripId: String?

    /// Last known location from the provider, for centering the map.
    var currentLocation: CLLocation? {
        locationProvider.currentLocation
    }

    init(core: SaplingCore) {
        self.core = core
    }

    /// Start delivering location fixes without recording a trip.
    /// Call once authorization is at least `.authorizedWhenInUse` so the
    /// blue dot and snap-to-location work before the user hits Record.
    func startLocationUpdates() {
        locationProvider.startUpdates()
    }

    func startRecording(name: String? = nil) {
        do {
            let tripId = try core.startRecording(name: name)
            currentTripId = tripId
            isRecording = true
            recordingStartedAt = Date()
            trackCoordinates = []
            distanceMeters = 0
            elevationGain = 0
            elapsedMs = 0
            pointCount = 0

            locationProvider.startUpdates()

            // Wall-clock display timer — ticks every second for smooth UX
            // regardless of GPS fix cadence. Distance, elevation, and the
            // stored track are still GPS-driven; this only drives the live
            // timer readout. The authoritative trip duration comes from
            // Rust's summary on stop.
            timerTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard let self, let start = self.recordingStartedAt else { continue }
                    self.elapsedMs = Int64(Date().timeIntervalSince(start) * 1000)
                }
            }

            // Detached so the blocking FFI + SQLite writes run off the main
            // thread. UI updates hop back via MainActor.run.
            recordingTask = Task.detached { [self] in
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
                                self.pointCount = update.pointCount
                                // elapsedMs is driven by wall-clock timerTask;
                                // Rust's update.elapsedMs surfaces on the
                                // trip summary at stopRecording.
                            }
                        }
                    } catch {
                        print("addLocation error: \(error)")
                        await MainActor.run { self.lastError = error.localizedDescription }
                    }
                }
            }
        } catch {
            print("startRecording error: \(error)")
            lastError = error.localizedDescription
        }
    }

    func stopRecording() {
        recordingTask?.cancel()
        recordingTask = nil
        timerTask?.cancel()
        timerTask = nil
        locationProvider.stopUpdates()

        // Capture track before clearing state
        let savedTrack = trackCoordinates

        do {
            let summary = try core.stopRecording()
            lastTripSummary = summary
            lastTripTrack = savedTrack
        } catch {
            print("stopRecording error: \(error)")
            lastError = error.localizedDescription
        }

        isRecording = false
        recordingStartedAt = nil
        currentTripId = nil
    }

    /// Dismiss the trip summary sheet.
    func dismissTripSummary() {
        lastTripSummary = nil
        lastTripTrack = []
    }
}
