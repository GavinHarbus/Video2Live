import AVFoundation

struct VideoRenderConfiguration {
    let videoComposition: AVMutableVideoComposition
    let geometry: VideoRenderGeometry
}

struct VideoCompositionBuilder {
    func makeConfiguration(
        for asset: AVAsset,
        framing: VideoFraming
    ) async throws -> VideoRenderConfiguration {
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw V2LError.noVideoTrack
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let geometry = framing.renderGeometry(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform
        )
        guard geometry.renderSize.width > 0, geometry.renderSize.height > 0 else {
            throw V2LError.invalidVideoFile
        }

        let trackTimeRange = try await videoTrack.load(.timeRange)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let frameDuration = nominalFrameRate > 0
            ? CMTime(seconds: 1 / Double(nominalFrameRate), preferredTimescale: 60_000)
            : CMTime(value: 1, timescale: 30)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(geometry.transform, at: trackTimeRange.start)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = trackTimeRange
        instruction.layerInstructions = [layerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = geometry.renderSize
        videoComposition.frameDuration = frameDuration
        videoComposition.instructions = [instruction]

        return VideoRenderConfiguration(
            videoComposition: videoComposition,
            geometry: geometry
        )
    }
}