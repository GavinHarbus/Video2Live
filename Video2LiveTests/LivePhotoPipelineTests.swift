import AVFoundation
import CoreVideo
import XCTest
@testable import Video2Live

final class LivePhotoPipelineTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
    }

    func testGeneratedPairHasMatchingMetadataAndH264Video() async throws {
        let sourceURL = temporaryDirectory.appendingPathComponent("source.mov")
        let sourceAsset = try await makeSourceVideo(at: sourceURL)
        let contentIdentifier = UUID().uuidString
        let heicURL = temporaryDirectory.appendingPathComponent("live.heic")
        let movURL = temporaryDirectory.appendingPathComponent("live.mov")
        let duration = try await sourceAsset.load(.duration)
        let keyFrameTime = CMTime(seconds: 0.1, preferredTimescale: 600)

        let heicWriter = HEICWriter()
        let image = try await heicWriter.extractKeyFrame(from: sourceAsset, at: keyFrameTime)
        try heicWriter.writeHEIC(
            image: image,
            contentIdentifier: contentIdentifier,
            to: heicURL
        )
        try await MOVWriter().writeMOV(
            from: sourceAsset,
            timeRange: CMTimeRange(start: .zero, duration: duration),
            contentIdentifier: contentIdentifier,
            stillImageTime: keyFrameTime,
            to: movURL
        )

        try await LivePhotoValidator().validate(
            heicURL: heicURL,
            movURL: movURL,
            expectedContentIdentifier: contentIdentifier,
            expectedDuration: duration,
            expectedStillImageTime: keyFrameTime
        )
    }

    private func makeSourceVideo(at url: URL) async throws -> AVURLAsset {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 64,
                AVVideoHeightKey: 64
            ]
        )
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 64,
                kCVPixelBufferHeightKey as String: 64
            ]
        )
        writer.add(input)
        guard writer.startWriting() else {
            throw V2LError.movExportFailed(writer.error?.localizedDescription ?? "Test writer failed")
        }
        writer.startSession(atSourceTime: .zero)

        for frameIndex in 0..<6 {
            while !input.isReadyForMoreMediaData {
                await Task.yield()
            }
            guard let pool = adaptor.pixelBufferPool else {
                throw V2LError.movExportFailed("Test pixel buffer pool is unavailable")
            }
            var optionalBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer)
            guard status == kCVReturnSuccess, let buffer = optionalBuffer else {
                throw V2LError.movExportFailed("Test pixel buffer creation failed")
            }
            fill(buffer: buffer, value: UInt8(frameIndex * 30))
            guard adaptor.append(
                buffer,
                withPresentationTime: CMTime(value: CMTimeValue(frameIndex), timescale: 30)
            ) else {
                throw V2LError.movExportFailed(writer.error?.localizedDescription ?? "Test frame failed")
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw V2LError.movExportFailed(writer.error?.localizedDescription ?? "Test writer failed")
        }
        return AVURLAsset(url: url)
    }

    private func fill(buffer: CVPixelBuffer, value: UInt8) {
        CVPixelBufferLockBaseAddress(buffer, [])
        if let address = CVPixelBufferGetBaseAddress(buffer) {
            memset(address, Int32(value), CVPixelBufferGetDataSize(buffer))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
    }
}