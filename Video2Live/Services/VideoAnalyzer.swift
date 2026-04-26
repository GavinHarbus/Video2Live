import AVFoundation

struct VideoAnalyzer {
    func analyze(url: URL) async throws -> (asset: AVURLAsset, duration: Double, size: CGSize) {
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ])

        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)

        guard let videoTrack = tracks.first else {
            throw V2LError.noVideoTrack
        }

        let size = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let transformedSize = size.applying(transform)
        let naturalSize = CGSize(
            width: abs(transformedSize.width),
            height: abs(transformedSize.height)
        )

        return (asset, duration.seconds, naturalSize)
    }
}
