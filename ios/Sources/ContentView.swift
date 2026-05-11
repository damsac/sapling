import SwiftUI
import CoreLocation
import MapLibre

/// Map tab — live recording, seed dropping, route building, and route navigation.
struct ContentView: View {
    var viewModel: RecordingViewModel
    var seedViewModel: SeedViewModel
    var tripListViewModel: TripListViewModel
    var routeViewModel: RouteBuilderViewModel
    @Binding var displayRoute: [CLLocationCoordinate2D]?
    @Binding var activeRoute: FfiRoute?

    @State private var showBackgroundModal: Bool = false
    @State private var showOfflineSheet: Bool = false
    @State private var showSeedList: Bool = false
    @State private var showRouteList: Bool = false
    @State private var showStopSheet: Bool = false
    @State private var showRouteSave: Bool = false
    @State private var routeSaveName: String = ""
    @State private var visibleBounds: MLNCoordinateBounds?
    @State private var snapToLocationTrigger: Bool = false
    private var offlineManager = OfflineMapManager.shared

    init(viewModel: RecordingViewModel, seedViewModel: SeedViewModel, tripListViewModel: TripListViewModel, routeViewModel: RouteBuilderViewModel, displayRoute: Binding<[CLLocationCoordinate2D]?>, activeRoute: Binding<FfiRoute?>) {
        self.viewModel = viewModel
        self.seedViewModel = seedViewModel
        self.tripListViewModel = tripListViewModel
        self.routeViewModel = routeViewModel
        self._displayRoute = displayRoute
        self._activeRoute = activeRoute
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TrailMapView(
                trackCoordinates: viewModel.trackCoordinates,
                userLocation: viewModel.currentLocation,
                userHeading: viewModel.currentHeading,
                seeds: seedViewModel.seeds,
                onLongPress: routeViewModel.isBuilding ? nil : { coordinate in
                    seedViewModel.startSeedCreation(at: coordinate)
                },
                onSeedTapped: routeViewModel.isBuilding ? nil : { seed in
                    seedViewModel.selectSeed(seed)
                },
                isRouteBuilding: routeViewModel.isBuilding,
                routeWaypoints: routeViewModel.isBuilding ? routeViewModel.waypoints : nil,
                routePath: routeViewModel.isBuilding ? routeViewModel.fullRouteCoordinates : nil,
                onRouteWaypointAdded: { coord in
                    routeViewModel.addWaypoint(coord)
                },
                isRouting: routeViewModel.isRouting,
                displayRoute: displayRoute,
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

            // Left-side floating controls
            VStack {
                HStack(alignment: .top) {
                    VStack(spacing: 8) {
                        VStack(spacing: 3) {
                            Button {
                                showSeedList = true
                            } label: {
                                Image(systemName: "leaf.fill")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(SaplingColors.brand, in: Circle())
                                    .shadow(color: SaplingColors.brand.opacity(0.45), radius: 6, y: 3)
                            }
                            Text("Seeds")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(SaplingColors.bark)
                        }

                        VStack(spacing: 3) {
                            Button {
                                if routeViewModel.isBuilding {
                                    withAnimation { routeViewModel.cancel() }
                                } else {
                                    displayRoute = nil
                                    activeRoute = nil
                                    withAnimation { routeViewModel.startBuilding() }
                                }
                            } label: {
                                Image(systemName: routeViewModel.isBuilding ? "xmark" : "point.3.filled.connected.trianglepath.dotted")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(routeViewModel.isBuilding ? SaplingColors.stopRecording : SaplingColors.ink)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        routeViewModel.isBuilding
                                            ? SaplingColors.stopRecording.opacity(0.12)
                                            : SaplingColors.parchment.opacity(0.92),
                                        in: Circle()
                                    )
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            }
                            Text(routeViewModel.isBuilding ? "Cancel" : "Route")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(routeViewModel.isBuilding ? SaplingColors.stopRecording : SaplingColors.bark)
                        }

                        VStack(spacing: 3) {
                            Button {
                                routeViewModel.loadRoutes()
                                showRouteList = true
                            } label: {
                                Image(systemName: "map")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(activeRoute != nil ? SaplingColors.brand : SaplingColors.ink)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        activeRoute != nil
                                            ? SaplingColors.brand.opacity(0.12)
                                            : SaplingColors.parchment.opacity(0.92),
                                        in: Circle()
                                    )
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            }
                            Text("Trips")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(activeRoute != nil ? SaplingColors.brand : SaplingColors.bark)
                        }

                        VStack(spacing: 3) {
                            OfflineMapButton(
                                packCount: offlineManager.packs.count,
                                action: { showOfflineSheet = true }
                            )
                            Text("Offline")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(SaplingColors.bark)
                        }

                        VStack(spacing: 3) {
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
                            Text("Find Me")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(SaplingColors.bark)
                        }

                        CompassWidget(heading: viewModel.currentHeading)
                    }
                    .padding(.leading, 16)
                    .padding(.top, viewModel.isRecording ? 80 : 60)

                    Spacer()
                }
                Spacer()
            }

            // Recording controls
            VStack {
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

                if routeViewModel.isBuilding {
                    RouteBuilderPanel(
                        waypointCount: routeViewModel.waypoints.count,
                        distanceMeters: routeViewModel.distanceMeters,
                        onUndo: { routeViewModel.undoLast() },
                        onCancel: {
                            withAnimation { routeViewModel.cancel() }
                        },
                        onSave: {
                            routeSaveName = ""
                            showRouteSave = true
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
                }

                if seedViewModel.isShowingTypePicker {
                    SeedTypePicker(
                        onSelect: { type in seedViewModel.selectType(type) },
                        onCancel: { seedViewModel.cancelCreation() }
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
                        onSave: { title, notes in seedViewModel.saveSeed(title: title, notes: notes) },
                        onCancel: { seedViewModel.cancelCreation() }
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

                if !seedViewModel.isShowingTypePicker
                    && !seedViewModel.isShowingQuickAdd
                    && !seedViewModel.isShowingDetail
                    && !routeViewModel.isBuilding
                {
                    VStack(spacing: 12) {
                        if let route = activeRoute, let routeCoords = displayRoute, !routeCoords.isEmpty {
                            ActiveRoutePanel(
                                route: route,
                                routeCoords: routeCoords,
                                userLocation: viewModel.currentLocation?.coordinate,
                                onEnd: {
                                    withAnimation {
                                        displayRoute = nil
                                        activeRoute = nil
                                    }
                                }
                            )
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
            .animation(.easeInOut(duration: 0.25), value: routeViewModel.isBuilding)

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
                    onDismiss: { viewModel.dismissTripSummary() },
                    onRename: { name in viewModel.renameLastTrip(name: name) },
                    onUpdateNotes: { notes in viewModel.updateLastTripNotes(notes: notes) },
                    onExportGpx: { tripListViewModel.exportGpx(trip: summary) }
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
        .sheet(isPresented: $showSeedList) {
            SeedListView(viewModel: seedViewModel, currentLocation: viewModel.currentLocation?.coordinate)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRouteList) {
            RouteListView(
                viewModel: routeViewModel,
                onSelectRoute: { route in
                    activeRoute = route
                    displayRoute = route.waypoints.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    }
                    snapToLocationTrigger.toggle()
                },
                onStartBuilding: {
                    showRouteList = false
                    displayRoute = nil
                    activeRoute = nil
                    withAnimation { routeViewModel.startBuilding() }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .alert("Name Your Route", isPresented: $showRouteSave) {
            TextField("Route name", text: $routeSaveName)
            Button("Save") {
                let name = routeSaveName.trimmingCharacters(in: .whitespaces)
                withAnimation { routeViewModel.saveRoute(name: name.isEmpty ? "Untitled Route" : name) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(formatDistance(routeViewModel.distanceMeters) + " · \(routeViewModel.waypoints.count) waypoints")
        }
        .alert("Route Error", isPresented: Binding(
            get: { routeViewModel.lastError != nil },
            set: { if !$0 { routeViewModel.lastError = nil } }
        )) {
            Button("OK") { routeViewModel.lastError = nil }
        } message: {
            Text(routeViewModel.lastError ?? "")
        }
        .sheet(isPresented: $showStopSheet) {
            StopRecordingSheet(
                distanceMeters: viewModel.distanceMeters,
                elevationGain: viewModel.elevationGain,
                elapsedMs: viewModel.elapsedMs,
                onResume: { showStopSheet = false },
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
        .onAppear {
            let status = LocationProvider.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                viewModel.startLocationUpdates()
            }
        }
    }

    private func handleRecordTap() {
        let status = LocationProvider.authorizationStatus
        switch status {
        case .authorizedAlways:
            viewModel.startRecording()
        case .authorizedWhenInUse:
            let hideModal = UserDefaults.standard.bool(forKey: "hideBackgroundLocationModal")
            if hideModal {
                viewModel.startRecording()
            } else {
                withAnimation { showBackgroundModal = true }
            }
        case .notDetermined:
            viewModel.startRecording()
        case .denied, .restricted:
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
                                Circle().stroke(.white, lineWidth: 2)
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
                    VStack(spacing: 1) {
                        Text("N")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.red)
                        Rectangle().fill(.red).frame(width: 2, height: 6)
                        Spacer()
                        Rectangle().fill(.secondary).frame(width: 1, height: 4)
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

// MARK: - Route Builder Panel

struct RouteBuilderPanel: View {
    let waypointCount: Int
    let distanceMeters: Double
    let onUndo: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(waypointCount == 0 ? "Tap map to add points" : formatDistance(distanceMeters))
                        .font(.headline)
                        .foregroundStyle(SaplingColors.ink)
                    Text("\(waypointCount) waypoint\(waypointCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(SaplingColors.bark)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: onUndo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.body.weight(.medium))
                            .foregroundStyle(waypointCount == 0 ? SaplingColors.bark.opacity(0.4) : SaplingColors.ink)
                            .frame(width: 36, height: 36)
                            .background(SaplingColors.stone, in: Circle())
                    }
                    .disabled(waypointCount == 0)

                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(SaplingColors.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(SaplingColors.stone, in: Capsule())
                    }

                    Button(action: onSave) {
                        Text("Save")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                waypointCount < 2 ? SaplingColors.brand.opacity(0.4) : SaplingColors.brand,
                                in: Capsule()
                            )
                    }
                    .disabled(waypointCount < 2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(SaplingColors.parchment.opacity(0.96), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(SaplingColors.brand.opacity(0.3), lineWidth: 1.5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }
}
