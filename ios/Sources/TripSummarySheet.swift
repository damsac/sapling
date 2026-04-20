import CoreLocation
import MapLibre
import MapLibreSwiftDSL
import MapLibreSwiftUI
import SwiftUI

struct TripSummarySheet: View {
    let summary: FfiTripSummary
    let trackCoordinates: [CLLocationCoordinate2D]
    let onDismiss: () -> Void
    let onRename: (String) -> Void
    let onUpdateNotes: (String?) -> Void
    let onExportGpx: () -> URL?

    @State private var isEditing = false
    @State private var editName = ""
    @State private var editNotes = ""
    @State private var gpxURL: URL? = nil
    @State private var showShareSheet = false

    private var parsedDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: summary.createdAt) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: summary.createdAt) ?? Date()
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(SaplingColors.bark.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 20) {
                    // Mini map
                    if !trackCoordinates.isEmpty {
                        SummaryMapView(trackCoordinates: trackCoordinates)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 16)
                    }

                    // Trip name + edit controls
                    VStack(spacing: 12) {
                        if isEditing {
                            VStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Trip Name")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(SaplingColors.bark)
                                    TextField("Trip name", text: $editName)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(SaplingColors.ink)
                                        .padding(10)
                                        .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 10))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Notes")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(SaplingColors.bark)
                                    TextField("Add notes about this trip…", text: $editNotes, axis: .vertical)
                                        .font(.body)
                                        .foregroundStyle(SaplingColors.ink)
                                        .lineLimit(3...8)
                                        .padding(10)
                                        .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 10))
                                }

                                HStack(spacing: 12) {
                                    Button("Cancel") {
                                        isEditing = false
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(SaplingColors.bark)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 12))

                                    Button("Save") {
                                        let name = editName.trimmingCharacters(in: .whitespaces)
                                        if !name.isEmpty { onRename(name) }
                                        let notes = editNotes.trimmingCharacters(in: .whitespaces)
                                        onUpdateNotes(notes.isEmpty ? nil : notes)
                                        isEditing = false
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(SaplingColors.brand, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        } else {
                            VStack(spacing: 6) {
                                HStack(alignment: .center, spacing: 10) {
                                    Text(summary.name)
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(SaplingColors.ink)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)

                                    Button {
                                        editName = summary.name
                                        editNotes = summary.notes ?? ""
                                        isEditing = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(SaplingColors.brand)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(SaplingColors.brand.opacity(0.12), in: Capsule())
                                    }

                                    Button {
                                        gpxURL = onExportGpx()
                                        if gpxURL != nil { showShareSheet = true }
                                    } label: {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(SaplingColors.brand)
                                            .padding(8)
                                            .background(SaplingColors.brand.opacity(0.12), in: Circle())
                                    }
                                }

                                Text(parsedDate, format: .dateTime.month(.wide).day().year())
                                    .font(.subheadline)
                                    .foregroundStyle(SaplingColors.bark)

                                if let notes = summary.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.subheadline)
                                        .foregroundStyle(SaplingColors.bark)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    if !isEditing {
                        StatsGrid(summary: summary)
                            .padding(.horizontal, 16)

                        if summary.seedCount > 0 {
                            HStack {
                                Image(systemName: "leaf.fill")
                                    .foregroundStyle(SaplingColors.brand)
                                Text("\(summary.seedCount) seed\(summary.seedCount == 1 ? "" : "s") dropped")
                                    .font(.subheadline)
                                    .foregroundStyle(SaplingColors.bark)
                            }
                            .padding(.horizontal, 16)
                        }

                        Button(action: onDismiss) {
                            Text("Done")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(SaplingColors.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .background(SaplingColors.parchment)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(false)
        .sheet(isPresented: $showShareSheet) {
            if let url = gpxURL {
                ShareSheet(url: url)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Stats Grid

private struct StatsGrid: View {
    let summary: FfiTripSummary

    var body: some View {
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ]

        LazyVGrid(columns: columns, spacing: 10) {
            StatCell(value: formatDistance(summary.distanceM), label: "Distance")
            StatCell(value: formatDuration(summary.durationMs), label: "Time")
            StatCell(value: formatElevation(summary.elevationGain), label: "Elev +")
            StatCell(value: formatElevation(summary.elevationLoss), label: "Elev -")
            if summary.durationMs > 0 && summary.distanceM > 0 {
                StatCell(value: formatPace(summary.distanceM, summary.durationMs), label: "Avg Pace")
            }
        }
        .padding(16)
        .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct StatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(SaplingColors.ink)
            Text(label)
                .font(.caption2)
                .foregroundStyle(SaplingColors.bark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(SaplingColors.parchment, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Summary Map (non-interactive)

private struct SummaryMapView: View {
    let trackCoordinates: [CLLocationCoordinate2D]

    var body: some View {
        let bounds = boundingBox(for: trackCoordinates)
        let center = bounds.center
        let zoom = zoomToFit(bounds: bounds)

        MapView(
            styleURL: URL(string: "https://tiles.openfreemap.org/styles/liberty")!,
            camera: .constant(.center(center, zoom: zoom))
        ) {
            let trailSource = ShapeSource(identifier: "summary-trail") {
                MLNPolylineFeature(coordinates: trackCoordinates)
            }

            LineStyleLayer(identifier: "summary-trail-line", source: trailSource)
                .lineColor(SaplingColors.trailUI)
                .lineWidth(4)
                .lineCap(.round)
                .lineJoin(.round)
        }
        .mapControls {
            LogoView()
                .position(.bottomLeft)
            AttributionButton()
                .position(.bottomRight)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Formatting Helpers

func formatDistance(_ meters: Double) -> String {
    if meters < 1000 {
        return String(format: "%.0f m", meters)
    } else {
        return String(format: "%.1f km", meters / 1000)
    }
}

func formatElevation(_ meters: Double) -> String {
    String(format: "%.0f m", meters)
}

func formatDuration(_ ms: Int64) -> String {
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

func formatPace(_ distanceM: Double, _ durationMs: Int64) -> String {
    let km = distanceM / 1000
    guard km > 0 else { return "--" }
    let hours = Double(durationMs) / 1000 / 3600
    let kmh = km / hours
    return String(format: "%.1f km/h", kmh)
}
