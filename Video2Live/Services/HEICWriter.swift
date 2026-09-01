import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct HEICWriter {
    func extractKeyFrame(
        from asset: AVURLAsset,
        at time: CMTime,
        framing: VideoFraming = VideoFraming()
    ) async throws -> CGImage {
        let configuration = try await VideoCompositionBuilder().makeConfiguration(
            for: asset,
            framing: framing
        )
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.videoComposition = configuration.videoComposition

        let (image, _) = try await generator.image(at: time)
        return image
    }

    func writeHEIC(image: CGImage, contentIdentifier: String, to outputURL: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            throw V2LError.heicWriteFailed
        }

        let properties: [CFString: Any] = [
            kCGImagePropertyMakerAppleDictionary: [
                MetadataConstants.makerAppleAssetIdentifierKey: contentIdentifier
            ]
        ]

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw V2LError.heicWriteFailed
        }
    }
}
