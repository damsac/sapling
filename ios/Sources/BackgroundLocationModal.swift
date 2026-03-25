import SwiftUI

struct BackgroundLocationModal: View {
    var onEnableSettings: () -> Void
    var onRecordAnyway: () -> Void
    @State private var dontShowAgain: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "location.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color(red: 0.29, green: 0.49, blue: 0.35))
                .padding(.top, 24)

            // Title
            Text("Background Recording")
                .font(.title3)
                .fontWeight(.semibold)

            // Body
            Text("Sapling records your trail when your phone is in your pocket. Enable \"Always Allow\" location access for uninterrupted recording.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            // Primary button — open Settings
            Button {
                if dontShowAgain {
                    UserDefaults.standard.set(true, forKey: "hideBackgroundLocationModal")
                }
                onEnableSettings()
            } label: {
                Text("Enable in Settings")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.29, green: 0.49, blue: 0.35))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 8)

            // Secondary button — record anyway
            Button {
                if dontShowAgain {
                    UserDefaults.standard.set(true, forKey: "hideBackgroundLocationModal")
                }
                onRecordAnyway()
            } label: {
                Text("Record Anyway")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.29, green: 0.49, blue: 0.35))
            }

            // Don't show again toggle — subtle
            Toggle(isOn: $dontShowAgain) {
                Text("Don't show me again")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .toggleStyle(.switch)
            .tint(Color(red: 0.29, green: 0.49, blue: 0.35))
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 32)
    }
}
