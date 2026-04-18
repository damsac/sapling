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
                .foregroundStyle(SaplingColors.brand)
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
                    .background(SaplingColors.brand)
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
                    .foregroundStyle(SaplingColors.brand)
            }

            // Don't show again toggle — subtle
            Toggle(isOn: $dontShowAgain) {
                Text("Don't show me again")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)
            .tint(SaplingColors.brand)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 32)
    }
}
