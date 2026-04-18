import SwiftUI

struct SeedDetailSheet: View {
    let seed: FfiSeed
    let onDismiss: () -> Void
    let onDelete: (FfiSeed) -> Void
    let onUpdate: (FfiSeed, String, String?) -> Void

    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var editNotes = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: seed.seedType.sfSymbol)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(seed.seedType.color, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    if isEditing {
                        TextField("Title", text: $editTitle)
                            .font(.headline.weight(.semibold))
                    } else {
                        Text(seed.title)
                            .font(.headline.weight(.semibold))
                    }
                    Text(seed.seedType.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(seed.seedType.color)
                }

                Spacer()

                if isEditing {
                    Button("Save") {
                        onUpdate(seed, editTitle, editNotes.isEmpty ? nil : editNotes)
                        isEditing = false
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(seed.seedType.color)
                } else {
                    Button(action: { isEditing = true; editTitle = seed.title; editNotes = seed.notes ?? "" }) {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                }
            }

            // Notes
            if isEditing {
                TextField("Notes (optional)", text: $editNotes, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3...6)
            } else if let notes = seed.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Details grid
            if !isEditing {
                VStack(spacing: 8) {
                    detailRow(icon: "location", label: "Location", value: formatCoordinate(seed.latitude, seed.longitude))

                    if let elevation = seed.elevation {
                        detailRow(icon: "arrow.up.right", label: "Elevation", value: String(format: "%.0f m", elevation))
                    }

                    detailRow(icon: "clock", label: "Created", value: formatDate(seed.createdAt))
                }
            }

            // Delete button
            if !isEditing {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Seed", systemImage: "trash")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.red)
                }
                .confirmationDialog("Delete this seed?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) { onDelete(seed) }
                    Button("Cancel", role: .cancel) {}
                }
            }

            if isEditing {
                Button("Cancel") {
                    isEditing = false
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func formatCoordinate(_ lat: Double, _ lon: Double) -> String {
        String(format: "%.5f, %.5f", lat, lon)
    }

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            let relative = RelativeDateTimeFormatter()
            relative.unitsStyle = .abbreviated
            return relative.localizedString(for: date, relativeTo: Date())
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            let relative = RelativeDateTimeFormatter()
            relative.unitsStyle = .abbreviated
            return relative.localizedString(for: date, relativeTo: Date())
        }
        return isoString
    }
}
