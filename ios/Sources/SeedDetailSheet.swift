import SwiftUI

struct SeedDetailSheet: View {
    let seed: FfiSeed
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header: type badge + title + dismiss
            HStack(spacing: 10) {
                Image(systemName: seed.seedType.sfSymbol)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(seed.seedType.color, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(seed.title)
                        .font(.headline)
                    Text(seed.seedType.displayName)
                        .font(.caption)
                        .foregroundStyle(seed.seedType.color)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            // Notes
            if let notes = seed.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Details grid
            VStack(spacing: 8) {
                detailRow(icon: "location", label: "Location", value: formatCoordinate(seed.latitude, seed.longitude))

                if let elevation = seed.elevation {
                    detailRow(icon: "arrow.up.right", label: "Elevation", value: String(format: "%.0f m", elevation))
                }

                detailRow(icon: "clock", label: "Created", value: formatDate(seed.createdAt))
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func formatCoordinate(_ lat: Double, _ lon: Double) -> String {
        let latStr = String(format: "%.5f", lat)
        let lonStr = String(format: "%.5f", lon)
        return "\(latStr), \(lonStr)"
    }

    private func formatDate(_ isoString: String) -> String {
        // Parse ISO8601 and display as relative or short date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            let relative = RelativeDateTimeFormatter()
            relative.unitsStyle = .abbreviated
            return relative.localizedString(for: date, relativeTo: Date())
        }
        // Fallback: try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            let relative = RelativeDateTimeFormatter()
            relative.unitsStyle = .abbreviated
            return relative.localizedString(for: date, relativeTo: Date())
        }
        return isoString
    }
}
