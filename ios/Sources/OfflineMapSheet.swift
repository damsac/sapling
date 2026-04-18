import SwiftUI
import MapLibre
import CoreLocation

// MARK: - Offline Map Sheet

/// Bottom sheet for managing offline map downloads.
/// Shows current viewport info, download button, and list of saved regions.
struct OfflineMapSheet: View {
    @Bindable var manager: OfflineMapManager
    let visibleBounds: MLNCoordinateBounds?
    let onDismiss: () -> Void

    @State private var regionName: String = ""
    @State private var showDeleteConfirmation: String? = nil

    private var estimate: (tileCount: Int, bytes: Int)? {
        guard let bounds = visibleBounds else { return nil }
        return OfflineMapManager.estimateSize(bounds: bounds)
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Download Section
                if let bounds = visibleBounds, let est = estimate {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            // Bounds info
                            HStack {
                                Image(systemName: "map")
                                    .foregroundStyle(.secondary)
                                Text("Current map viewport")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            // Estimate
                            HStack {
                                Label(
                                    "~\(OfflineMapManager.formatEstimatedSize(bytes: est.bytes))",
                                    systemImage: "internaldrive"
                                )
                                .font(.subheadline)

                                Spacer()

                                Text("\(est.tileCount) tiles, z10-z14")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // Name field
                            TextField("Region name (optional)", text: $regionName)
                                .textFieldStyle(.roundedBorder)
                                .font(.subheadline)

                            // Download / progress
                            if manager.isDownloading {
                                VStack(spacing: 6) {
                                    ProgressView(value: manager.activeDownloadProgress)
                                        .tint(.accentColor)

                                    Text("\(Int(manager.activeDownloadProgress * 100))% downloaded")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Button {
                                    let name = regionName.isEmpty
                                        ? "Map area \(Date().formatted(date: .abbreviated, time: .omitted))"
                                        : regionName
                                    manager.downloadRegion(
                                        name: name,
                                        bounds: bounds
                                    )
                                    regionName = ""
                                } label: {
                                    Label("Download for Offline Use", systemImage: "arrow.down.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Download Area")
                    }
                }

                // MARK: - Saved Regions
                if !manager.packs.isEmpty {
                    Section {
                        ForEach(manager.packs) { pack in
                            OfflinePackRow(
                                pack: pack,
                                isActive: manager.activeDownloadId == pack.id,
                                onPause: { manager.pausePack(id: pack.id) },
                                onResume: { manager.resumePack(id: pack.id) }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    manager.deletePack(id: pack.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("Saved Regions")
                            Spacer()
                            Text(manager.formattedTotalSize)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: - Empty State
                if manager.packs.isEmpty && !manager.isDownloading {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No offline maps yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Pan the map to your trail area, then download tiles for offline use.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("Offline Maps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                }
            }
        }
    }
}

// MARK: - Pack Row

struct OfflinePackRow: View {
    let pack: OfflinePackInfo
    let isActive: Bool
    let onPause: () -> Void
    let onResume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pack.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(pack.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if pack.isComplete {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SaplingColors.brand)
                        .font(.caption)
                    Text("Downloaded \(pack.formattedDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("z\(Int(pack.minZoom))-\(Int(pack.maxZoom))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                // In-progress
                VStack(spacing: 4) {
                    ProgressView(value: pack.progress)
                        .tint(.accentColor)
                    HStack {
                        Text("\(Int(pack.progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if isActive {
                            Button {
                                onPause()
                            } label: {
                                Text("Pause")
                                    .font(.caption)
                            }
                        } else {
                            Button {
                                onResume()
                            } label: {
                                Text("Resume")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
