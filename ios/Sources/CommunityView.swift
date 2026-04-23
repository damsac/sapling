import SwiftUI

struct CommunityView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "leaf.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(SaplingColors.brand)

                VStack(spacing: 10) {
                    Text("Community seeds are coming soon.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(SaplingColors.ink)
                        .multilineTextAlignment(.center)

                    Text("When it launches, you'll find water sources, camp spots, and hidden gems shared by people you trust — with fuzzy locations so wild places stay wild.")
                        .font(.subheadline)
                        .foregroundStyle(SaplingColors.bark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Link(destination: URL(string: "mailto:sapling@example.com?subject=Waitlist")!) {
                    Text("Join the waitlist")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(SaplingColors.brand, in: Capsule())
                }

                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(SaplingColors.parchment.ignoresSafeArea())
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
