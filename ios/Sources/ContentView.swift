import SwiftUI
import CoreLocation
import MapLibre

struct ContentView: View {
    @State private var viewModel: RecordingViewModel
    @State private var seedViewModel: SeedViewModel
    @State private var tripListViewModel: TripListViewModel
    @State private var showBackgroundModal: Bool = false
    @State private var showOfflineSheet: Bool = false
    @State private var showTripList: Bool = false
    @State private var showSeedList: Bool = false
    @State private var showStopSheet: Bool = false
    @State private var visibleBounds: MLNCoordinateBounds?
    @State private var initError: String? = nil
    @State private var snapToLocationTrigger: Bool = false
    private var offlineManager = OfflineMapManager.shared

    init() {
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        let dbPath = documentsDir.appendingPathComponent("sapling.db").path
        do {
            let core = try SaplingCore(dbPath: dbPath)
            _viewModel = State(initialValue: RecordingViewModel(core: core))
            _seedViewModel = State(initialValue: SeedViewModel(core: core))
            _tripListViewModel = State(initialValue: TripListViewModel(core: core))
        } catch {
            // Create a fallback in-memory core so views can still render
            let fallbackCore = try! SaplingCore(dbPath: ":memory:")
            _viewModel = State(initialValue: RecordingViewModel(core: fallbackCore))
            _seedViewModel = State(initialValue: SeedViewModel(core: fallbackCore))
            _tripListViewModel = State(initialValue: TripListViewModel(core: fallbackCore))
            _initError = State(initialValue: "Failed to open database: \(error.localizedDescription)")
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen map with seed markers and gestures
            TrailMapView(
                trackCoordinates: viewModel.trackCoordinates,
                userLocation: viewModel.currentLocation,
                userHeading: viewModel.currentHeading,
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
                },
                snapToLocationTrigger: $snapToLocationTrigger
            )
            .ignoresSafeArea()

            // Top bar buttons — all on the left side
            VStack {
                HStack(alignment: .top) {
                    VStack(spacing: 12) {
                        Button {
                            tripListViewModel.loadTrips()
                            showTripList = true
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.body.weight(.medium))
                                .foregroundStyle(SaplingColors.ink)
                                .frame(width: 40, height: 40)
                                .background(SaplingColors.parchment.opacity(0.92), in: Circle())
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        }

                        Button {
                            showSeedList = true
                        } label: {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.body.weight(.medium))
                                .foregroundStyle(SaplingColors.ink)
                                .frame(width: 40, height: 40)
                                .background(SaplingColors.parchment.opacity(0.92), in: Circle())
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        }

                        OfflineMapButton(
                            packCount: offlineManager.packs.count,
                            action: { showOfflineSheet = true }
                        )

                        Button {
                            snapToLocationTrigger.toggle()
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.body.weight(.medium))
                                .foregroundStyle(SaplingColors.ink)
                                .frame(width: 40, height: 40)
                                .background(SaplingColors.parchment.opacity(0.92), in: Circle())
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        }

                        CompassWidget(heading: viewModel.currentHeading)
                    }
                    .padding(.leading, 16)
                    .padding(.top, viewModel.isRecording ? 80 : 60)

                    Spacer()
                }

                Spacer()
            }

            // Recording controls overlay
            VStack {
                // Stats bar at top when recording
                if viewModel.isRecording {
                    HStack(spacing: 0) {
                        LiveStat(value: formatDistance(viewModel.distanceMeters), label: "Distance")
                        Divider().frame(height: 32)
                        LiveStat(value: formatElevation(viewModel.elevationGain), label: "Gain")
                        Divider().frame(height: 32)
                        LiveStat(value: formatDuration(viewModel.elapsedMs), label: "Time")
                    }
                    .padding(.vertical, 12)
                    .background(SaplingColors.parchment.opacity(0.92), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(SaplingColors.brand.opacity(0.35), lineWidth: 1.5)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
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
                        onDismiss: { seedViewModel.dismissDetail() },
                        onDelete: { seedViewModel.deleteSeed($0) },
                        onUpdate: { seedViewModel.updateSeed($0, title: $1, notes: $2) }
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
                                withAnimation { showStopSheet = true }
                            } else {
                                handleRecordTap()
                            }
                        } label: {
                            Circle()
                                .fill(viewModel.isRecording ? SaplingColors.stopRecording : SaplingColors.recording)
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
                    },
                    onRename: { name in
                        viewModel.renameLastTrip(name: name)
                    },
                    onUpdateNotes: { notes in
                        viewModel.updateLastTripNotes(notes: notes)
                    },
                    onExportGpx: {
                        tripListViewModel.exportGpx(trip: summary)
                    }
                )
            }
        }
        .sheet(isPresented: $showOfflineSheet) {
            OfflineMapSheet(
                manager: offlineManager,
                visibleBounds: visibleBounds,
                onDismiss: { showOfflineSheet = false }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showTripList) {
            TripListView(viewModel: tripListViewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSeedList) {
            SeedListView(viewModel: seedViewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showStopSheet) {
            StopRecordingSheet(
                distanceMeters: viewModel.distanceMeters,
                elevationGain: viewModel.elevationGain,
                elapsedMs: viewModel.elapsedMs,
                onResume: {
                    showStopSheet = false
                },
                onSave: {
                    showStopSheet = false
                    viewModel.stopRecording()
                },
                onDiscard: {
                    showStopSheet = false
                    viewModel.discardRecording()
                }
            )
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.lastError != nil || seedViewModel.lastError != nil },
            set: { if !$0 { viewModel.lastError = nil; seedViewModel.lastError = nil } }
        )) {
            Button("OK") { viewModel.lastError = nil; seedViewModel.lastError = nil }
        } message: {
            Text(viewModel.lastError ?? seedViewModel.lastError ?? "An unknown error occurred.")
        }
        .alert("Database Error", isPresented: Binding(
            get: { initError != nil },
            set: { if !$0 { initError = nil } }
        )) {
            Button("OK") { initError = nil }
        } message: {
            Text(initError ?? "An unknown error occurred.")
        }
        .fontDesign(.rounded)
        .onAppear {
            // Start location stream on launch if the user has already granted
            // permission, so the blue dot and snap-to-location work before
            // they hit Record. If status is .notDetermined, we let the first
            // Record tap trigger the prompt.
            let status = LocationProvider.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                viewModel.startLocationUpdates()
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

// MARK: - Live Recording Stat Cell

private struct LiveStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.monospacedDigit())
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(SaplingColors.bark)
        }
        .frame(maxWidth: .infinity)
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
                            .foregroundStyle(SaplingColors.ink)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(SaplingColors.parchment.opacity(0.92), in: Capsule())
        .padding(.horizontal, 16)
    }
}

// MARK: - Compass Widget

/// A floating compass rose. The "N" label points to true north at all times,
/// rotating against the phone's heading. When the heading is not yet valid
/// (uncalibrated magnetometer), renders a neutral placeholder.
struct CompassWidget: View {
    let heading: CLHeading?

    private var direction: Double? {
        guard let heading, heading.headingAccuracy >= 0 else { return nil }
        return heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(SaplingColors.parchment.opacity(0.92))
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            if let direction {
                ZStack {
                    // North marker — red label plus a tick emanating inward
                    VStack(spacing: 1) {
                        Text("N")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.red)
                        Rectangle()
                            .fill(.red)
                            .frame(width: 2, height: 6)
                        Spacer()
                        Rectangle()
                            .fill(.secondary)
                            .frame(width: 1, height: 4)
                        Text("S")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 44, height: 44)
                }
                .rotationEffect(.degrees(-direction))
            } else {
                Image(systemName: "location.north.line")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityLabel("Compass, \(direction.map { "pointing \(Int($0))°" } ?? "calibrating")")
    }
}
