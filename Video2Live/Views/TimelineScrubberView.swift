import SwiftUI
import AVFoundation

struct TimelineScrubberView: View {
    let duration: Double
    let sourceStartTime: CMTime
    let asset: AVURLAsset
    @Binding var rangeStart: Double
    let rangeDuration: Double

    @State private var thumbnails: [NSImage] = []
    @State private var isDragging = false

    private let thumbnailCount = 20
    private let height: CGFloat = 50

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Select a \(String(format: "%.0f", rangeDuration))-second clip")
                .font(.caption)
                .foregroundStyle(.secondary)

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

                    // Dimmed overlay (before selection)
                    Rectangle()
                        .fill(.black.opacity(0.5))
                        .frame(width: startOffset(width: width), height: height)

                    // Dimmed overlay (after selection)
                    Rectangle()
                        .fill(.black.opacity(0.5))
                        .frame(width: width - endOffset(width: width), height: height)
                        .offset(x: endOffset(width: width))

                    // Selection border
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .frame(width: selectionWidth(width: width), height: height)
                        .offset(x: startOffset(width: width))
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            let fraction = value.location.x / width
                            let time = fraction * duration
                            let maxStart = duration - rangeDuration
                            rangeStart = min(max(0, time - rangeDuration / 2), maxStart)
                        }
                        .onEnded { _ in
                            isDragging = false
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
