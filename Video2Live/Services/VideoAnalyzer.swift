import AVFoundation

struct VideoAnalyzer {
    func analyze(url: URL) async throws -> (
        asset: AVURLAsset,
        timeRange: CMTimeRange,
        duration: Double,
        size: CGSize
    ) {
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ])

        let isReadable = try await asset.load(.isReadable)
        let isPlayable = try await asset.load(.isPlayable)
        guard isReadable, isPlayable else {
            throw V2LError.unsupportedVideoEncoding
        }

        let tracks = try await asset.loadTracks(withMediaType: .video)

        guard let videoTrack = tracks.first else {
            throw V2LError.noVideoTrack
        }

        let timeRange = try await videoTrack.load(.timeRange)
        let duration = timeRange.duration.seconds
        guard timeRange.isValid, !timeRange.isEmpty, duration.isFinite, duration > 0 else {
            throw V2LError.invalidVideoFile
        }

        let size = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let transformedSize = size.applying(transform)
        let naturalSize = CGSize(
            width: abs(transformedSize.width),
            height: abs(transformedSize.height)
        )
        guard naturalSize.width > 0, naturalSize.height > 0 else {
            throw V2LError.invalidVideoFile
        }

        return (asset, timeRange, duration, naturalSize)
    }
}
