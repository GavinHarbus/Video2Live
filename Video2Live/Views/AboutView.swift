import SwiftUI

struct AboutView: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            // App Name & Version
            VStack(spacing: 4) {
                Text("Video2Live")
                    .font(.title.bold())
                Text("Version \(appVersion)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Description
            Text("A native macOS app that converts video files into Live Photos. Pick a video, select a 3-second clip, and import the result directly into your Photos library.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 340)

            Divider()
                .frame(width: 200)

            // Developer Info
            VStack(spacing: 6) {
                Text("Developed by Gavin Schnee")
                    .font(.callout)

                Link("gavinschneestudio.org", destination: URL(string: "https://gavinschneestudio.org/")!)
                    .font(.callout)
            }

            Text("\u{00A9} 2025 Gavin Schnee. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(30)
        .frame(width: 420, height: 380)
    }
}
