import AVFoundation
import Foundation

enum LivePhotoDestination {
    case photos
    case folder(URL)
}

enum LivePhotoOutput: Equatable {
    case photos
    case files(ExportedLivePhoto)
}

@Observable
final class LivePhotoGenerator {
    var progress: Double = 0
    var stage: ConversionStage = .preparing

    func generate(
        project: VideoProject,
        destination: LivePhotoDestination = .photos
    ) async throws -> LivePhotoOutput {
        guard let asset = project.asset else {
            throw V2LError.invalidVideoFile
        }

        await update(stage: .preparing, progress: 0)

        let importer = PhotosImporter()
        if case .photos = destination {
            try await importer.ensureAuthorization()
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer { try? FileManager.default.removeItem(at: tempDir) }

        let heicURL = tempDir.appendingPathComponent("live.heic")
        let movURL = tempDir.appendingPathComponent("live.mov")

        let timeRange = project.selectedTimeRange
        let keyFrameTime = project.keyFrameTime
        let stillImageTime = project.stillImageTime

        // Step 1: Extract key frame
        await update(stage: .extractingCover, progress: 0.1)
        try Task.checkCancellation()
        let heicWriter = HEICWriter()
        let keyFrame = try await heicWriter.extractKeyFrame(from: asset, at: keyFrameTime)
        try Task.checkCancellation()
        await update(stage: .extractingCover, progress: 0.25)

        // Step 2: Generate shared UUID
        let contentIdentifier = UUID().uuidString

        // Step 3: Write HEIC with metadata
        try heicWriter.writeHEIC(image: keyFrame, contentIdentifier: contentIdentifier, to: heicURL)
        try Task.checkCancellation()
        await update(stage: .encodingVideo, progress: 0.35)

        // Step 4: Write MOV with metadata
        let movWriter = MOVWriter()
        try await movWriter.writeMOV(
            from: asset,
            timeRange: timeRange,
            contentIdentifier: contentIdentifier,
            stillImageTime: stillImageTime,
            to: movURL
        )
        try Task.checkCancellation()
        await update(stage: .validating, progress: 0.75)

        // Step 5: Validate the paired metadata before saving
        try await LivePhotoValidator().validate(
            heicURL: heicURL,
            movURL: movURL,
            expectedContentIdentifier: contentIdentifier,
            expectedDuration: timeRange.duration,
            expectedStillImageTime: stillImageTime
        )
        try Task.checkCancellation()
        await update(stage: .saving, progress: 0.9)

        // Step 6: Save the generated pair
        let output: LivePhotoOutput
        switch destination {
        case .photos:
            try await importer.importLivePhoto(heicURL: heicURL, movURL: movURL)
            output = .photos
        case .folder(let directoryURL):
            let suggestedName = project.sourceURL?.deletingPathExtension().lastPathComponent
                ?? "Live Photo"
            let files = try LivePhotoExporter().exportPair(
                heicURL: heicURL,
                movURL: movURL,
                suggestedName: suggestedName,
                to: directoryURL
            )
            output = .files(files)
        }
        try Task.checkCancellation()
        await update(stage: .saving, progress: 1.0)
        return output
    }

    private func update(stage: ConversionStage, progress: Double) async {
        await MainActor.run {
            self.stage = stage
            self.progress = progress
        }
    }
}
