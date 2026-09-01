import SwiftUI

struct FramingControlsView: View {
    let sourceSize: CGSize
    let sourceHasAudio: Bool
    @Binding var aspectRatio: OutputAspectRatio
    @Binding var position: Double
    @Binding var includesAudio: Bool

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

            Divider()
                .frame(height: 18)

            Toggle(isOn: $includesAudio) {
                Label(
                    audioLabel,
                    systemImage: audioIcon
                )
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .disabled(!sourceHasAudio)
            .help(sourceHasAudio ? "Include audio" : "Source video has no audio")

            Spacer(minLength: 0)
        }
        .frame(minHeight: 24)
    }

    private var audioLabel: String {
        guard sourceHasAudio else { return "No Audio" }
        return includesAudio ? "Sound" : "Muted"
    }

    private var audioIcon: String {
        sourceHasAudio && includesAudio ? "speaker.wave.2.fill" : "speaker.slash.fill"
    }
}