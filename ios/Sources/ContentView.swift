import SwiftUI

struct ContentView: View {
    @State private var viewModel: RecordingViewModel

    init() {
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        let dbPath = documentsDir.appendingPathComponent("sapling.db").path
        let core = try! SaplingCore(dbPath: dbPath)
        _viewModel = State(initialValue: RecordingViewModel(core: core))
    }

    var body: some View {
        ZStack {
            // Full-screen map
            TrailMapView(
                trackCoordinates: viewModel.trackCoordinates,
                userLocation: viewModel.currentLocation
            )
            .ignoresSafeArea()

            // Recording controls overlay
            VStack {
                // Stats bar at top when recording
                if viewModel.isRecording {
                    HStack(spacing: 16) {
                        VStack {
                            Text(formatDistance(viewModel.distanceMeters))
                                .font(.title3.monospacedDigit())
                                .fontWeight(.semibold)
                            Text("Distance")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            Text(formatElevation(viewModel.elevationGain))
                                .font(.title3.monospacedDigit())
                                .fontWeight(.semibold)
                            Text("Gain")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            Text(formatDuration(viewModel.elapsedMs))
                                .font(.title3.monospacedDigit())
                                .fontWeight(.semibold)
                            Text("Time")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top)
                }

                Spacer()

                // Record / stop button at bottom
                Button {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.startRecording()
                    }
                } label: {
                    Circle()
                        .fill(viewModel.isRecording ? .red : .green)
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: viewModel.isRecording ? "stop.fill" : "record.circle")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Formatters

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }

    private func formatElevation(_ meters: Double) -> String {
        String(format: "%.0f m", meters)
    }

    private func formatDuration(_ ms: Int64) -> String {
        let totalSeconds = ms / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
