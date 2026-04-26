import SwiftUI

struct ConvertButton: View {
    let state: ConversionState
    let progress: Double
    let action: () -> Void
    let resetAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            switch state {
            case .idle, .analyzing:
                EmptyView()

            case .ready:
                Button(action: action) {
                    Label("Convert to Live Photo", systemImage: "livephoto")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            case .converting:
                ProgressView(value: progress)
                    .frame(width: 200)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

            case .completed:
                Label("Live Photo saved to Photos!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Convert Another", action: resetAction)
                    .buttonStyle(.bordered)

            case .failed(let message):
                VStack(alignment: .leading, spacing: 4) {
                    Label("Conversion failed", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Try Again", action: resetAction)
                    .buttonStyle(.bordered)
            }
        }
        .animation(.default, value: state)
    }
}
