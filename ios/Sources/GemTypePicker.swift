import SwiftUI

struct GemTypePicker: View {
    let onSelect: (FfiGemType) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header with cancel
            HStack {
                Text("Drop a Gem")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            // Single row of 5 gem types
            HStack(spacing: 0) {
                ForEach(allGemTypes, id: \.displayName) { type in
                    Button {
                        onSelect(type)
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(type.color)
                                .frame(width: 52, height: 52)
                                .overlay {
                                    Image(systemName: type.sfSymbol)
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                }

                            Text(type.displayName)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 12)
    }
}
