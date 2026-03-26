import SwiftUI
import CoreLocation

struct ContentView: View {
    @State private var viewModel: RecordingViewModel
    @State private var seedViewModel: SeedViewModel
    @State private var showBackgroundModal: Bool = false

    init() {
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        let dbPath = documentsDir.appendingPathComponent("sapling.db").path
        let core = try! SaplingCore(dbPath: dbPath)
        _viewModel = State(initialValue: RecordingViewModel(core: core))
        _seedViewModel = State(initialValue: SeedViewModel(core: core))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen map with seed markers and gestures
            TrailMapView(
                trackCoordinates: viewModel.trackCoordinates,
                userLocation: viewModel.currentLocation,
                seeds: seedViewModel.seeds,
                onLongPress: { coordinate in
                    seedViewModel.startSeedCreation(at: coordinate)
                },
                onSeedTapped: { seed in
                    seedViewModel.selectSeed(seed)
                }
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

                // Seed creation sheets (anchored to bottom)
                if seedViewModel.isShowingTypePicker {
                    SeedTypePicker(
                        onSelect: { type in
                            seedViewModel.selectType(type)
                        },
                        onCancel: {
                            seedViewModel.cancelCreation()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
                }

                if seedViewModel.isShowingQuickAdd,
                   let type = seedViewModel.pendingSeedType,
                   let coord = seedViewModel.pendingSeedCoordinate
                {
                    SeedQuickAdd(
                        seedType: type,
                        coordinate: coord,
                        onSave: { title, notes in
                            seedViewModel.saveSeed(title: title, notes: notes)
                        },
                        onCancel: {
                            seedViewModel.cancelCreation()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
                }

                if seedViewModel.isShowingDetail, let seed = seedViewModel.selectedSeed {
                    SeedDetailSheet(
                        seed: seed,
                        onDismiss: {
                            seedViewModel.dismissDetail()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
                }

                // Record / stop button at bottom (hidden during seed sheets)
                if !seedViewModel.isShowingTypePicker
                    && !seedViewModel.isShowingQuickAdd
                    && !seedViewModel.isShowingDetail
                {
                    Button {
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                        } else {
                            handleRecordTap()
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
            .animation(.easeInOut(duration: 0.25), value: seedViewModel.isShowingTypePicker)
            .animation(.easeInOut(duration: 0.25), value: seedViewModel.isShowingQuickAdd)
            .animation(.easeInOut(duration: 0.25), value: seedViewModel.isShowingDetail)

            // Background location permission modal
            if showBackgroundModal {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showBackgroundModal = false }
                    }

                BackgroundLocationModal(
                    onEnableSettings: {
                        withAnimation { showBackgroundModal = false }
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    onRecordAnyway: {
                        withAnimation { showBackgroundModal = false }
                        viewModel.startRecording()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showBackgroundModal)
    }

    // MARK: - Record Tap Authorization Check

    private func handleRecordTap() {
        let status = LocationProvider.authorizationStatus

        switch status {
        case .authorizedAlways:
            // Full background access — start immediately
            viewModel.startRecording()

        case .authorizedWhenInUse:
            let hideModal = UserDefaults.standard.bool(forKey: "hideBackgroundLocationModal")
            if hideModal {
                // User opted out of the reminder — just record
                viewModel.startRecording()
            } else {
                withAnimation { showBackgroundModal = true }
            }

        case .notDetermined:
            // System will prompt automatically when location updates start
            viewModel.startRecording()

        case .denied, .restricted:
            // Location fully disabled — show the modal so they can go to Settings
            withAnimation { showBackgroundModal = true }

        @unknown default:
            viewModel.startRecording()
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
