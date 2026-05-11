import CoreLocation
import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private struct Page {
        let icon: String
        let iconColor: Color
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(
            icon: "leaf.fill",
            iconColor: SaplingColors.brand,
            title: "Welcome to Sapling",
            body: "Your offline-ready companion for hiking, backpacking, and exploring the outdoors."
        ),
        Page(
            icon: "mappin.and.ellipse",
            iconColor: SaplingColors.accent,
            title: "Drop Seeds Along the Way",
            body: "Mark camp spots, water sources, viewpoints, and hidden gems. Tap the leaf button on the map to drop a seed at your location."
        ),
        Page(
            icon: "figure.hiking",
            iconColor: SaplingColors.brand,
            title: "Explore Trails & Record Hikes",
            body: "Search thousands of nearby trails with elevation data, then record your route and save it to My Trips."
        ),
        Page(
            icon: "location.fill",
            iconColor: SaplingColors.brand,
            title: "Enable Location",
            body: "Allow location access so Sapling can find trails near you, track your hikes, and navigate in real time."
        )
    ]

    var body: some View {
        ZStack {
            SaplingColors.stone.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageCard(pages[index]).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 16) {
                    pageIndicator

                    Button {
                        if currentPage == pages.count - 1 {
                            CLLocationManager().requestWhenInUseAuthorization()
                            hasSeenOnboarding = true
                        } else {
                            withAnimation(.easeInOut) { currentPage += 1 }
                        }
                    } label: {
                        Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(SaplingColors.brand, in: RoundedRectangle(cornerRadius: 14))
                    }

                    if currentPage < pages.count - 1 {
                        Button("Skip") { hasSeenOnboarding = true }
                            .font(.subheadline)
                            .foregroundStyle(SaplingColors.bark)
                    } else {
                        Color.clear.frame(height: 20)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .padding(.top, 12)
            }
        }
        .fontDesign(.rounded)
    }

    private func pageCard(_ page: Page) -> some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.12))
                    .frame(width: 128, height: 128)
                Image(systemName: page.icon)
                    .font(.system(size: 56))
                    .foregroundStyle(page.iconColor)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(SaplingColors.ink)
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .font(.callout)
                    .foregroundStyle(SaplingColors.bark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? SaplingColors.brand : SaplingColors.bark.opacity(0.25))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.easeInOut, value: currentPage)
            }
        }
    }
}
