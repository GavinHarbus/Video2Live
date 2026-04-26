import AVFoundation
import Foundation

@Observable
final class LivePhotoGenerator {
    var progress: Double = 0

    func generate(project: VideoProject) async throws {
        guard let asset = project.asset else {
            throw V2LError.invalidVideoFile
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer { try? FileManager.default.removeItem(at: tempDir) }

        let heicURL = tempDir.appendingPathComponent("live.heic")
        let movURL = tempDir.appendingPathComponent("live.mov")

        let timeRange = project.selectedTimeRange
        let keyFrameTime = project.keyFrameTime

        // Step 1: Extract key frame
        let heicWriter = HEICWriter()
        let keyFrame = try await heicWriter.extractKeyFrame(from: asset, at: keyFrameTime)
        await MainActor.run { progress = 0.2 }

        // Step 2: Generate shared UUID
        let contentIdentifier = UUID().uuidString

        // Step 3: Write HEIC with metadata
        try heicWriter.writeHEIC(image: keyFrame, contentIdentifier: contentIdentifier, to: heicURL)
        await MainActor.run { progress = 0.4 }

        // Step 4: Write MOV with metadata
        let movWriter = MOVWriter()
        try await movWriter.writeMOV(
            from: asset,
            timeRange: timeRange,
            contentIdentifier: contentIdentifier,
            to: movURL
        )
        await MainActor.run { progress = 0.7 }

        // Step 5: Import to Photos
        let importer = PhotosImporter()
        try await importer.importLivePhoto(heicURL: heicURL, movURL: movURL)
        await MainActor.run { progress = 1.0 }
    }
}
