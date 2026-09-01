import SwiftUI

struct FramingControlsView: View {
    let sourceSize: CGSize
    @Binding var aspectRatio: OutputAspectRatio
    @Binding var position: Double

    private var cropAxis: CropAxis {
        VideoFraming(aspectRatio: aspectRatio, position: position)
            .cropAxis(in: sourceSize)
    }

    var body: some View {
        HStack(spacing: 8) {
            Label("Frame", systemImage: "crop")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Output aspect ratio", selection: $aspectRatio) {
                ForEach(OutputAspectRatio.allCases) { aspectRatio in
                    Text(aspectRatio.title)
                        .tag(aspectRatio)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)

            if cropAxis != .none {
                Button {
                    position = 0
                } label: {
                    Image(systemName: "scope")
                }
                .buttonStyle(.borderless)
                .help("Center crop")
                .accessibilityLabel("Center crop")
                .disabled(abs(position) < 0.001)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 24)
    }
}