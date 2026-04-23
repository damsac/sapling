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
                .fill(SaplingColors.bark.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text("End Recording?")
                .font(.title3.weight(.bold))
                .foregroundStyle(SaplingColors.ink)
                .padding(.bottom, 20)

            // Live stats
            HStack(spacing: 8) {
                StatPill(value: formatDistance(distanceMeters), label: "Distance")
                StatPill(value: formatElevation(elevationGain), label: "Gain")
                StatPill(value: formatDuration(elapsedMs), label: "Time")
            }
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
                        .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(SaplingColors.ink)
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
        .background(SaplingColors.parchment)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }
}

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(SaplingColors.ink)
            Text(label)
                .font(.caption2)
                .foregroundStyle(SaplingColors.bark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 12))
    }
}
