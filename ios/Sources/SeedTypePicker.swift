import SwiftUI

struct SeedTypePicker: View {
    let onSelect: (FfiSeedType) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header with cancel
            HStack {
                Text("Plant a Seed")
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

            // Single row of 5 seed types
            HStack(spacing: 0) {
                ForEach(allSeedTypes, id: \.displayName) { type in
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
