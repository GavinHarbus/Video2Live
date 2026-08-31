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

        return (asset, timeRange, duration, naturalSize)
    }
}
