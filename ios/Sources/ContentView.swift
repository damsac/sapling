import SwiftUI
import CoreLocation
import MapLibre

struct ContentView: View {
    @State private var viewModel: RecordingViewModel
    @State private var seedViewModel: SeedViewModel
    @State private var showBackgroundModal: Bool = false
    @State private var showOfflineSheet: Bool = false
    @State private var visibleBounds: MLNCoordinateBounds?
    private var offlineManager = OfflineMapManager.shared

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
                },
                pendingSeed: seedViewModel.pendingSeed,
                onPendingSeedDrag: { coordinate in
                    seedViewModel.updatePendingSeedPosition(coordinate)
                },
                onPendingSeedConfirm: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        seedViewModel.confirmPendingSeed()
                    }
                },
                onPendingSeedCancel: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        seedViewModel.cancelPendingSeed()
                    }
                },
                onVisibleBoundsChanged: { bounds in
                    visibleBounds = bounds
                }
            )
            .ignoresSafeArea()

            // Offline map button — top trailing
            VStack {
                HStack {
                    Spacer()
                    OfflineMapButton(
                        packCount: offlineManager.packs.count,
                        action: { showOfflineSheet = true }
                    )
                    .padding(.trailing, 16)
                    .padding(.top, 60)
                }
                Spacer()
            }

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

                // Seed quick-drop bar + record/stop button (hidden during seed sheets)
                if !seedViewModel.isShowingTypePicker
                    && !seedViewModel.isShowingQuickAdd
                    && !seedViewModel.isShowingDetail
                {
                    VStack(spacing: 16) {
                        // Quick-drop seed bar — only visible while recording
                        if viewModel.isRecording {
                            SeedQuickDropBar { type in
                                guard let location = viewModel.currentLocation else { return }
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    seedViewModel.quickDropSeed(
                                        type: type,
                                        at: location.coordinate
                                    )
                                }
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

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
            }
            .animation(.easeInOut(duration: 0.25), value: seedViewModel.isShowingTypePicker)
            .animation(.easeInOut(duration: 0.25), value: seedViewModel.isShowingQuickAdd)
            .animation(.easeInOut(duration: 0.25), value: seedViewModel.isShowingDetail)
            .animation(.easeInOut(duration: 0.25), value: viewModel.isRecording)
            .animation(.easeInOut(duration: 0.25), value: seedViewModel.pendingSeed)

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
        .sheet(isPresented: Binding(
            get: { viewModel.lastTripSummary != nil },
            set: { if !$0 { viewModel.dismissTripSummary() } }
        )) {
            if let summary = viewModel.lastTripSummary {
                TripSummarySheet(
                    summary: summary,
                    trackCoordinates: viewModel.lastTripTrack,
                    onDismiss: {
                        viewModel.dismissTripSummary()
                    }
                )
            }
        }
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

}

// MARK: - Seed Quick-Drop Bar

/// Horizontal row of 5 seed type buttons in a frosted glass pill.
struct SeedQuickDropBar: View {
    let onSelect: (FfiSeedType) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(allSeedTypes, id: \.displayName) { type in
                Button {
                    onSelect(type)
                } label: {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(type.color)
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: type.sfSymbol)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                            .overlay {
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                            }

                        Text(type.displayName)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, 16)
    }
}
