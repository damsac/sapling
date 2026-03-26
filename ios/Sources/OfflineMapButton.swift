import SwiftUI

// MARK: - Offline Map Button

/// Small button overlay on the map that opens the offline maps sheet.
/// Shows a cloud/download icon with a badge when packs exist.
struct OfflineMapButton: View {
    let packCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "arrow.down.to.line.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                // Badge showing saved pack count
                if packCount > 0 {
                    Text("\(packCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(.green, in: Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
        .accessibilityLabel("Offline maps")
        .accessibilityHint(packCount > 0
            ? "\(packCount) regions downloaded"
            : "Download map tiles for offline use"
        )
    }
}
