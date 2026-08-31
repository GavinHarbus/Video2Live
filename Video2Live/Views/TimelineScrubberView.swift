import SwiftUI
import AVFoundation

struct TimelineScrubberView: View {
    let duration: Double
    let sourceStartTime: CMTime
    let asset: AVURLAsset
    @Binding var rangeStart: Double
    let rangeDuration: Double
    @Binding var coverTime: Double

    @State private var thumbnails: [NSImage] = []
    @State private var editingMode: EditingMode = .cover

    private let thumbnailCount = 20
    private let height: CGFloat = 50

    private enum EditingMode: String, CaseIterable, Identifiable {
        case clip
        case cover

        var id: Self { self }
    }

    private var canTrim: Bool {
        duration > rangeDuration
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if canTrim {
                    Picker("Timeline editing mode", selection: $editingMode) {
                        Label("Clip", systemImage: "scissors")
                            .tag(EditingMode.clip)
                        Label("Cover", systemImage: "photo")
                            .tag(EditingMode.cover)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 180)
                } else {
                    Label("Cover", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label(formatTime(coverTime), systemImage: "photo.fill")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.orange)
            }

            GeometryReader { geometry in
                let width = geometry.size.width

                ZStack(alignment: .leading) {
                    // Thumbnail strip
                    HStack(spacing: 0) {
                        ForEach(0..<thumbnails.count, id: \.self) { index in
                            Image(nsImage: thumbnails[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: width / CGFloat(thumbnailCount), height: height)
                                .clipped()
                        }
                    }

                    if canTrim {
                        Rectangle()
                            .fill(.black.opacity(0.5))
                            .frame(width: startOffset(width: width), height: height)

                        Rectangle()
                            .fill(.black.opacity(0.5))
                            .frame(width: width - endOffset(width: width), height: height)
                            .offset(x: endOffset(width: width))
                    }

                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .frame(width: selectionWidth(width: width), height: height)
                        .offset(x: startOffset(width: width))

                    VStack(spacing: 0) {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 8))
                        Rectangle()
                            .frame(width: 2)
                    }
                    .foregroundStyle(.orange)
                    .frame(width: 16, height: height)
                    .offset(x: coverOffset(width: width) - 8)
                    .shadow(color: .black.opacity(0.7), radius: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = min(max(0, value.location.x / width), 1)
                            let time = fraction * duration

                            if editingMode == .clip, canTrim {
                                let maxStart = duration - rangeDuration
                                rangeStart = min(max(0, time - rangeDuration / 2), maxStart)
                            } else {
                                coverTime = min(max(rangeStart, time), rangeStart + rangeDuration)
                            }
                        }
                )
            }
            .frame(height: height)

            // Time labels
            HStack {
                Text(formatTime(rangeStart))
                Spacer()
                Text(formatTime(rangeStart + rangeDuration))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .task {
            await generateThumbnails()
        }
    }

    private func startOffset(width: CGFloat) -> CGFloat {
        CGFloat(rangeStart / duration) * width
    }

    private func endOffset(width: CGFloat) -> CGFloat {
        CGFloat((rangeStart + rangeDuration) / duration) * width
    }

    private func selectionWidth(width: CGFloat) -> CGFloat {
        CGFloat(rangeDuration / duration) * width
    }

    private func coverOffset(width: CGFloat) -> CGFloat {
        CGFloat(coverTime / duration) * width
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func generateThumbnails() async {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 120, height: 120)

        var images: [NSImage] = []
        for i in 0..<thumbnailCount {
            let time = CMTimeAdd(
                sourceStartTime,
                CMTime(
                    seconds: duration * Double(i) / Double(thumbnailCount),
                    preferredTimescale: 600
                )
            )
            do {
                let (cgImage, _) = try await generator.image(at: time)
                images.append(NSImage(cgImage: cgImage, size: NSSize(width: 60, height: 60)))
            } catch {
                images.append(NSImage(size: NSSize(width: 60, height: 60)))
            }
        }

        await MainActor.run {
            thumbnails = images
        }
    }
}
