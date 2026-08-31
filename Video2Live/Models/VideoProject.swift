import Foundation
import AVFoundation

@Observable
final class VideoProject {
    static let maximumClipDuration = 3.0

    var sourceURL: URL?
    var sourceTimeRange: CMTimeRange = .zero
    var duration: Double = 0
    var naturalSize: CGSize = .zero
    var state: ConversionState = .idle

    // For long videos: user-selected range
    var rangeStart: Double = 0
    var rangeDuration: Double = maximumClipDuration
    var coverTime: Double = maximumClipDuration / 2

    // The actual AVURLAsset, loaded after analysis
    var asset: AVURLAsset?

    var isLongVideo: Bool {
        duration > rangeDuration
    }

    var selectedTimeRange: CMTimeRange {
        let start = CMTimeAdd(
            sourceTimeRange.start,
            CMTime(seconds: rangeStart, preferredTimescale: 600)
        )
        let duration = CMTime(seconds: rangeDuration, preferredTimescale: 600)

        return CMTimeRange(start: start, duration: duration)
    }

    var keyFrameTime: CMTime {
        CMTimeAdd(
            sourceTimeRange.start,
            CMTime(seconds: coverTime, preferredTimescale: 600)
        )
    }

    var stillImageTime: CMTime {
        CMTime(seconds: coverTime - rangeStart, preferredTimescale: 600)
    }

    func configureClip(for videoDuration: Double) {
        rangeDuration = min(Self.maximumClipDuration, videoDuration)
        rangeStart = max(0, (videoDuration - rangeDuration) / 2)
        coverTime = rangeStart + rangeDuration / 2
    }

    func setRangeStart(_ newValue: Double) {
        let clampedStart = min(max(0, newValue), max(0, duration - rangeDuration))
        let offset = coverTime - rangeStart
        rangeStart = clampedStart
        setCoverTime(clampedStart + offset)
    }

    func setCoverTime(_ newValue: Double) {
        let frameDuration = 1.0 / 30.0
        let upperBound = rangeStart + max(0, rangeDuration - frameDuration)
        coverTime = min(max(rangeStart, newValue), upperBound)
    }

    func reset() {
        sourceURL = nil
        sourceTimeRange = .zero
        duration = 0
        naturalSize = .zero
        state = .idle
        rangeStart = 0
        rangeDuration = Self.maximumClipDuration
        coverTime = Self.maximumClipDuration / 2
        asset = nil
    }
}
