import Foundation
import AVFoundation

@Observable
final class VideoProject {
    var sourceURL: URL?
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
        if isLongVideo {
            let start = CMTime(seconds: rangeStart, preferredTimescale: 600)
            let dur = CMTime(seconds: rangeDuration, preferredTimescale: 600)
            return CMTimeRange(start: start, duration: dur)
        } else {
            return CMTimeRange(start: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600))
        }
    }

    var keyFrameTime: CMTime {
        let range = selectedTimeRange
        return CMTimeAdd(range.start, CMTimeMultiplyByFloat64(range.duration, multiplier: 0.5))
    }

    func reset() {
        sourceURL = nil
        duration = 0
        naturalSize = .zero
        state = .idle
        rangeStart = 0
        rangeDuration = 3.0
        asset = nil
    }
}
