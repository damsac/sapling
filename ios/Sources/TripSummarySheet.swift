import CoreLocation
import MapLibre
import MapLibreSwiftDSL
import MapLibreSwiftUI
import SwiftUI

struct TripSummarySheet: View {
    let summary: FfiTripSummary
    let trackCoordinates: [CLLocationCoordinate2D]
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 20) {
                    // Mini map with trail
                    if !trackCoordinates.isEmpty {
                        SummaryMapView(trackCoordinates: trackCoordinates)
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 16)
                    }

                    // Trip name and date
                    VStack(spacing: 4) {
                        Text(summary.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(Date(), format: .dateTime.month(.wide).day().year())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)

                    // Stats grid
                    StatsGrid(summary: summary)
                        .padding(.horizontal, 16)

                    // Seed count (placeholder until trip-seed linkage)
                    if summary.seedCount > 0 {
                        HStack {
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(SaplingColors.brand)
                            Text("\(summary.seedCount) seed\(summary.seedCount == 1 ? "" : "s") dropped")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                    }

                    // Done button
                    Button(action: onDismiss) {
                        Text("Done")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(.regularMaterial)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(false)
    }
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

        LazyVGrid(columns: columns, spacing: 12) {
            StatCell(value: formatDistance(summary.distanceM), label: "Distance")
            StatCell(value: formatDuration(summary.durationMs), label: "Time")
            StatCell(value: formatElevation(summary.elevationGain), label: "Elev +")
            StatCell(value: formatElevation(summary.elevationLoss), label: "Elev -")
            if summary.durationMs > 0 && summary.distanceM > 0 {
                StatCell(value: formatPace(summary.distanceM, summary.durationMs), label: "Avg Pace")
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
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
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
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
