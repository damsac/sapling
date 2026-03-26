import CoreLocation
import SwiftUI

struct SeedQuickAdd: View {
    let seedType: FfiSeedType
    let coordinate: CLLocationCoordinate2D
    let onSave: (String, String?) -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var showNotes: Bool = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Type badge
            HStack(spacing: 8) {
                Image(systemName: seedType.sfSymbol)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(seedType.color, in: Circle())

                Text(seedType.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(seedType.color)

                Spacer()

                Button("Cancel", action: onCancel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Title field
            TextField("Name this seed", text: $title)
                .font(.title3.weight(.medium))
                .textFieldStyle(.plain)
                .padding(.horizontal)
                .focused($titleFocused)

            // Notes toggle + field
            VStack(spacing: 8) {
                if !showNotes {
                    Button {
                        showNotes = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text("Add notes")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }
                } else {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .font(.subheadline)
                        .textFieldStyle(.plain)
                        .lineLimit(3...6)
                        .padding(.horizontal)
                }
            }

            // Coordinate display
            HStack(spacing: 4) {
                Image(systemName: "location")
                    .font(.caption2)
                Text(formatCoordinate(coordinate))
                    .font(.caption.monospacedDigit())
            }
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            // Save button
            Button {
                let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
                let finalTitle = trimmedTitle.isEmpty ? seedType.defaultTitle : trimmedTitle
                let finalNotes: String? = showNotes && !notes.trimmingCharacters(in: .whitespaces).isEmpty
                    ? notes.trimmingCharacters(in: .whitespaces)
                    : nil
                onSave(finalTitle, finalNotes)
            } label: {
                Text("Save Seed")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(seedType.color, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 12)
        .onAppear {
            title = seedType.defaultTitle
            titleFocused = true
        }
    }

    private func formatCoordinate(_ coord: CLLocationCoordinate2D) -> String {
        let lat = String(format: "%.5f", coord.latitude)
        let lon = String(format: "%.5f", coord.longitude)
        return "\(lat), \(lon)"
    }
}
