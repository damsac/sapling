import SwiftUI

struct StopRecordingSheet: View {
    let distanceMeters: Double
    let elevationGain: Double
    let elapsedMs: Int64
    let onResume: () -> Void
    let onSave: () -> Void
    let onDiscard: () -> Void

    @State private var showDiscardConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            Text("End Recording?")
                .font(.title3.weight(.bold))
                .padding(.bottom, 20)

            // Live stats
            HStack(spacing: 0) {
                StatPill(value: formatDistance(distanceMeters), label: "Distance")
                Divider().frame(height: 36)
                StatPill(value: formatElevation(elevationGain), label: "Gain")
                Divider().frame(height: 36)
                StatPill(value: formatDuration(elapsedMs), label: "Time")
            }
            .padding(.vertical, 14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .padding(.bottom, 28)

            // Actions
            VStack(spacing: 12) {
                Button(action: onSave) {
                    Text("Save Trip")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(SaplingColors.brand, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }

                Button(action: onResume) {
                    Text("Resume")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.primary)
                }

                Button(role: .destructive) {
                    showDiscardConfirm = true
                } label: {
                    Text("Discard")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .confirmationDialog("Discard this recording?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
                    Button("Discard", role: .destructive) { onDiscard() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This trip will not be saved.")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(.regularMaterial)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }
}

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
