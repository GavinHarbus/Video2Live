import SwiftUI

struct AboutView: View {
    static let privacyPolicyURL = URL(string: "https://gavinschneestudio.org/privacy.html")!

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 20) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 88, height: 88)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Video2LivePhoto")
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Text("Video to Live Photo, entirely on your Mac.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Text("A native macOS app that converts video files into Live Photos. Pick a clip and cover frame, preview the result, and save it directly to your Photos library.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 24) {
                privacyPoint("On-device", icon: "macbook")
                privacyPoint("No tracking", icon: "eye.slash")
                privacyPoint("Add-only Photos", icon: "photo.badge.plus")
            }

            Divider()

            HStack(alignment: .center) {
                Text("© 2026 Gavin Schnee Studio. All Rights Reserved.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                Link(destination: URL(string: "https://gavinschneestudio.org/")!) {
                    Label("Website", systemImage: "globe")
                }
                .buttonStyle(.link)

                Link(destination: Self.privacyPolicyURL) {
                    Label("Privacy", systemImage: "hand.raised")
                }
                .buttonStyle(.link)
            }
        }
        .padding(32)
        .frame(width: 520)
    }

    private func privacyPoint(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
    }
}
