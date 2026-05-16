import SwiftUI
import CoreLocation

struct ActiveRoutePanel: View {
    let route: FfiRoute
    let routeCoords: [CLLocationCoordinate2D]
    let userLocation: CLLocationCoordinate2D?
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Float
    let onEnd: () -> Void
    let onDownload: () -> Void

    private var total: Double { totalRouteLength(routeCoords) }

    private var remaining: Double {
        guard let loc = userLocation else { return total }
        return distanceRemaining(routeCoords, user: loc)
    }

    private var progress: Double {
        guard total > 0 else { return 0 }
        return max(0, min(1, 1 - remaining / total))
    }

    private var estimatedMinutesLeft: Int {
        let stats = elevationStats(from: route.waypoints)
        let gainLeft = stats.hasData ? stats.gain * (1 - progress) : 0
        return naismithMinutes(distanceM: remaining, elevationGainM: gainLeft)
    }

    private var offRoute: Bool {
        guard let loc = userLocation, routeCoords.count >= 2 else { return false }
        return distanceFromRoute(routeCoords, user: loc) > 150
    }

    private var nextTurn: BearingChange? {
        guard let loc = userLocation else { return nil }
        return nextBearingChange(routeCoords, user: loc)
    }

    var body: some View {
        VStack(spacing: 0) {
            if offRoute {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                    Text("Off route — return to trail")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(SaplingColors.accent)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 14, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 14
                ))
            }

            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(route.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SaplingColors.ink)
                        HStack(spacing: 6) {
                            Text(formatDistance(remaining) + " left")
                            Text("·")
                            Text("~" + formatDurationMinutes(estimatedMinutesLeft))
                        }
                        .font(.caption2)
                        .foregroundStyle(SaplingColors.bark)
                    }

                    Spacer()

                    Button(action: onEnd) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(SaplingColors.ink)
                            .frame(width: 28, height: 28)
                            .background(SaplingColors.stone, in: Circle())
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(SaplingColors.stone)
                            .frame(height: 6)
                        Capsule()
                            .fill(SaplingColors.brand)
                            .frame(width: geo.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)

                if let turn = nextTurn, turn.distanceM < 5000 {
                    HStack(spacing: 6) {
                        Image(systemName: turnIcon(turn.label))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SaplingColors.brand)
                        Text("In \(formatDistance(turn.distanceM)), \(turn.label)")
                            .font(.caption)
                            .foregroundStyle(SaplingColors.ink)
                        Spacer()
                    }
                }

                if !isDownloaded {
                    HStack(spacing: 6) {
                        if isDownloading {
                            ProgressView(value: downloadProgress)
                                .tint(SaplingColors.brand)
                                .frame(maxWidth: .infinity)
                            Text("\(Int(downloadProgress * 100))%")
                                .font(.caption2)
                                .foregroundStyle(SaplingColors.bark)
                                .monospacedDigit()
                        } else {
                            Button(action: onDownload) {
                                Label("Save offline", systemImage: "arrow.down.to.line.circle")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(SaplingColors.brand)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(SaplingColors.brand.opacity(0.1), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, offRoute ? 10 : 14)
            .background(offRoute ? SaplingColors.parchment : SaplingColors.parchment.opacity(0.96))
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: offRoute ? 0 : 14,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 14,
                topTrailingRadius: offRoute ? 0 : 14
            ))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(SaplingColors.brand.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .padding(.horizontal, 16)
    }

    private func turnIcon(_ label: String) -> String {
        if label.contains("right") { return "arrow.turn.up.right" }
        if label.contains("left")  { return "arrow.turn.up.left" }
        return "arrow.up"
    }
}
