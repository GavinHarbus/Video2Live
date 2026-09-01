import SwiftUI
import AVFoundation

struct TimelineScrubberView: View {
    let duration: Double
    let sourceStartTime: CMTime
    let asset: AVURLAsset
    @Binding var rangeStart: Double
    let rangeDuration: Double
    @Binding var coverTime: Double
    let onCoverScrub: (Double) -> Void
    let onCoverScrubEnded: () -> Void

    @State private var thumbnails: [NSImage] = []
    @State private var editingMode: EditingMode = .cover
    @State private var pendingRangeStart: Double?
    @State private var pendingCoverTime: Double?
    @State private var dragCoverOffset: Double?

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

    private var displayedRangeStart: Double {
        pendingRangeStart ?? rangeStart
    }

    private var displayedCoverTime: Double {
        pendingCoverTime ?? coverTime
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

                Label(formatTime(displayedCoverTime), systemImage: "photo.fill")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.orange)
            }

            GeometryReader { geometry in
                let width = geometry.size.width

                ZStack(alignment: .leading) {
                    // Thumbnail strip
                    if thumbnails.isEmpty {
                        Rectangle()
                            .fill(.quaternary)
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        HStack(spacing: 0) {
                            ForEach(0..<thumbnails.count, id: \.self) { index in
                                Image(nsImage: thumbnails[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: width / CGFloat(thumbnailCount), height: height)
                                    .clipped()
                            }
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
                                if dragCoverOffset == nil {
                                    dragCoverOffset = coverTime - rangeStart
                                }

                                let maxStart = duration - rangeDuration
                                let newRangeStart = min(max(0, time - rangeDuration / 2), maxStart)
                                let coverOffset = dragCoverOffset ?? rangeDuration / 2
                                pendingRangeStart = newRangeStart
                                pendingCoverTime = constrainedCoverTime(
                                    newRangeStart + coverOffset,
                                    rangeStart: newRangeStart
                                )
                            } else {
                                let newCoverTime = constrainedCoverTime(
                                    time,
                                    rangeStart: displayedRangeStart
                                )
                                coverTime = newCoverTime
                                onCoverScrub(newCoverTime)
                            }
                        }
                        .onEnded { _ in
                            if editingMode == .clip, let pendingRangeStart {
                                rangeStart = pendingRangeStart
                            } else {
                                onCoverScrubEnded()
                            }

                            pendingRangeStart = nil
                            pendingCoverTime = nil
                            dragCoverOffset = nil
                        }
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    editingMode == .clip ? "Selected clip" : "Cover frame"
                )
                .accessibilityValue(accessibilityValue)
                .accessibilityAdjustableAction { direction in
                    adjustTimeline(direction)
                }
            }
            .frame(height: height)

            // Time labels
            HStack {
                Text(formatTime(displayedRangeStart))
                Spacer()
                Text(formatTime(displayedRangeStart + rangeDuration))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .task {
            await generateThumbnails()
        }
    }

    private func startOffset(width: CGFloat) -> CGFloat {
        CGFloat(displayedRangeStart / duration) * width
    }

    private func endOffset(width: CGFloat) -> CGFloat {
        CGFloat((displayedRangeStart + rangeDuration) / duration) * width
    }

    private func selectionWidth(width: CGFloat) -> CGFloat {
        CGFloat(rangeDuration / duration) * width
    }

    private func coverOffset(width: CGFloat) -> CGFloat {
        CGFloat(displayedCoverTime / duration) * width
    }

    private func constrainedCoverTime(_ time: Double, rangeStart: Double) -> Double {
        let lastFrameTime = rangeStart + max(0, rangeDuration - 1.0 / 30.0)
        return min(max(rangeStart, time), lastFrameTime)
    }

    private func formatTime(_ seconds: Double) -> String {
        let roundedSeconds = (seconds * 10).rounded() / 10
        let mins = Int(roundedSeconds) / 60
        let secs = roundedSeconds - Double(mins * 60)
        return String(format: "%d:%04.1f", mins, secs)
    }

    private var accessibilityValue: String {
        if editingMode == .clip, canTrim {
            return "\(formatTime(displayedRangeStart)) to \(formatTime(displayedRangeStart + rangeDuration))"
        }
        return formatTime(displayedCoverTime)
    }

    private func adjustTimeline(_ direction: AccessibilityAdjustmentDirection) {
        let adjustment = direction == .increment ? 0.1 : -0.1
        if editingMode == .clip, canTrim {
            let newStart = min(
                max(0, rangeStart + adjustment),
                max(0, duration - rangeDuration)
            )
            rangeStart = newStart
        } else {
            let newCoverTime = constrainedCoverTime(
                coverTime + adjustment,
                rangeStart: rangeStart
            )
            coverTime = newCoverTime
            onCoverScrub(newCoverTime)
            onCoverScrubEnded()
        }
    }

    private func generateThumbnails() async {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 120, height: 120)

        var images: [NSImage] = []
        for i in 0..<thumbnailCount {
            guard !Task.isCancelled else { return }
            let time = CMTimeAdd(
                sourceStartTime,
                CMTime(
                    seconds: duration * Double(i) / Double(thumbnailCount),
                    preferredTimescale: 600
                )
            )
            do {
                let (cgImage, _) = try await generator.image(at: time)
                guard !Task.isCancelled else { return }
                images.append(NSImage(cgImage: cgImage, size: NSSize(width: 60, height: 60)))
            } catch {
                guard !Task.isCancelled else { return }
                images.append(NSImage(size: NSSize(width: 60, height: 60)))
            }
        }

        guard !Task.isCancelled else { return }
        await MainActor.run {
            thumbnails = images
        }
    }
}
