import Foundation
import AVFoundation

@Observable
final class VideoProject {
    var sourceURL: URL?
    var sourceTimeRange: CMTimeRange = .zero
    var duration: Double = 0
    var naturalSize: CGSize = .zero
    var state: ConversionState = .idle

    // For long videos: user-selected range
    var rangeStart: Double = 0
    var rangeDuration: Double = 3.0

    // The actual AVURLAsset, loaded after analysis
    var asset: AVURLAsset?

    var isLongVideo: Bool {
        duration > 5.0
    }

    var selectedTimeRange: CMTimeRange {
        let localStart = isLongVideo ? rangeStart : 0
        let selectedDuration = isLongVideo ? rangeDuration : duration
        let start = CMTimeAdd(
            sourceTimeRange.start,
            CMTime(seconds: localStart, preferredTimescale: 600)
        )
        let duration = CMTime(seconds: selectedDuration, preferredTimescale: 600)

        return CMTimeRange(start: start, duration: duration)
    }

    var keyFrameTime: CMTime {
        let range = selectedTimeRange
        return CMTimeAdd(range.start, CMTimeMultiplyByFloat64(range.duration, multiplier: 0.5))
    }

    func reset() {
        sourceURL = nil
        sourceTimeRange = .zero
        duration = 0
        naturalSize = .zero
        state = .idle
        rangeStart = 0
        rangeDuration = 3.0
        asset = nil
    }
}
