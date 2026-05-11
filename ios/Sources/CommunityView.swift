import SwiftUI

struct CommunityView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    FuzzySeedHero()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("HOW IT WORKS")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SaplingColors.bark)
                            .kerning(0.8)

                        conceptRow(
                            icon: "drop.fill",
                            color: SaplingColors.brand,
                            title: "Drop a seed",
                            body: "Share a water source, camp spot, or hidden viewpoint. Only your trusted circle can see it."
                        )
                        conceptRow(
                            icon: "location.slash.fill",
                            color: SaplingColors.accent,
                            title: "Fuzzy by design",
                            body: "Exact coordinates are never published. Seeds appear in the right area — close enough to find, vague enough to protect."
                        )
                        conceptRow(
                            icon: "person.2.fill",
                            color: .blue,
                            title: "Trust-gated",
                            body: "Seeds travel through your network, not to strangers. Wild places stay wild."
                        )
                    }

                    VStack(spacing: 8) {
                        Text("Launching in Phase 3")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SaplingColors.ink)
                        Text("The mechanic above is exactly how it will work — we're building it now.")
                            .font(.caption)
                            .foregroundStyle(SaplingColors.bark)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(SaplingColors.brand.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(SaplingColors.brand.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(SaplingColors.parchment.ignoresSafeArea())
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func conceptRow(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SaplingColors.ink)
                Text(body)
                    .font(.callout)
                    .foregroundStyle(SaplingColors.bark)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct FuzzySeedHero: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(SaplingColors.stone)

            Circle()
                .fill(SaplingColors.brand.opacity(0.05))
                .frame(width: 200, height: 200)
            Circle()
                .stroke(SaplingColors.brand.opacity(0.12), lineWidth: 1)
                .frame(width: 200, height: 200)

            Circle()
                .fill(SaplingColors.brand.opacity(0.10))
                .frame(width: 130, height: 130)
            Circle()
                .stroke(SaplingColors.brand.opacity(0.18), lineWidth: 1)
                .frame(width: 130, height: 130)

            Circle()
                .fill(SaplingColors.brand.opacity(0.18))
                .frame(width: 70, height: 70)

            Circle()
                .fill(SaplingColors.brand)
                .frame(width: 14, height: 14)

            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .font(.caption2)
                    Text("Water source · ~500 m fuzzy radius")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(SaplingColors.brand)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 16)
            }
        }
        .frame(height: 240)
    }
}
