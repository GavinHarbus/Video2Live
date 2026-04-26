import AVFoundation

struct MOVWriter {
    func writeMOV(
        from sourceAsset: AVURLAsset,
        timeRange: CMTimeRange,
        contentIdentifier: String,
        to outputURL: URL
    ) async throws {
        let composition = AVMutableComposition()

        // Insert video track
        let videoTracks = try await sourceAsset.loadTracks(withMediaType: .video)
        if let sourceVideoTrack = videoTracks.first {
            let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            try compositionVideoTrack?.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)

            let transform = try await sourceVideoTrack.load(.preferredTransform)
            compositionVideoTrack?.preferredTransform = transform
        }

        // Insert audio track if available
        let audioTracks = try await sourceAsset.loadTracks(withMediaType: .audio)
        if let sourceAudioTrack = audioTracks.first {
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            try compositionAudioTrack?.insertTimeRange(timeRange, of: sourceAudioTrack, at: .zero)
        }

        // Build metadata
        let contentIdItem = AVMutableMetadataItem()
        contentIdItem.key = MetadataConstants.contentIdentifierKey as NSString
        contentIdItem.keySpace = .quickTimeMetadata
        contentIdItem.value = contentIdentifier as NSString
        contentIdItem.dataType = kCMMetadataBaseDataType_UTF8 as String

        let stillImageTimeItem = AVMutableMetadataItem()
        stillImageTimeItem.key = MetadataConstants.stillImageTimeKey as NSString
        stillImageTimeItem.keySpace = .quickTimeMetadata
        stillImageTimeItem.value = 0 as NSNumber
        stillImageTimeItem.dataType = kCMMetadataBaseDataType_SInt8 as String

        // Export
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw V2LError.movExportFailed("Failed to create export session")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.metadata = [contentIdItem, stillImageTimeItem]

        await exportSession.export()

        switch exportSession.status {
        case .completed:
            // Verify metadata was written; if not, re-export with AVAssetWriter
            if try await !verifyMetadata(at: outputURL, expectedIdentifier: contentIdentifier) {
                try FileManager.default.removeItem(at: outputURL)
                try await writeWithAssetWriter(
                    composition: composition,
                    contentIdentifier: contentIdentifier,
                    to: outputURL
                )
            }
        case .failed:
            let message = exportSession.error?.localizedDescription ?? "Unknown error"
            throw V2LError.movExportFailed(message)
        case .cancelled:
            throw V2LError.movExportFailed("Export was cancelled")
        default:
            throw V2LError.movExportFailed("Unexpected export status: \(exportSession.status.rawValue)")
        }
    }

    private func verifyMetadata(at url: URL, expectedIdentifier: String) async throws -> Bool {
        let asset = AVURLAsset(url: url)
        let metadata = try await asset.load(.metadata)
        return metadata.contains { item in
            item.key as? String == MetadataConstants.contentIdentifierKey
        }
    }

    private func writeWithAssetWriter(
        composition: AVMutableComposition,
        contentIdentifier: String,
        to outputURL: URL
    ) async throws {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        // Video track
        let videoTracks = try await composition.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw V2LError.movExportFailed("No video track in composition")
        }

        let videoSettings = try await videoWriterSettings(for: videoTrack)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.transform = try await videoTrack.load(.preferredTransform)
        videoInput.expectsMediaDataInRealTime = false

        if writer.canAdd(videoInput) {
            writer.add(videoInput)
        }

        // Audio track
        let audioTracks = try await composition.loadTracks(withMediaType: .audio)
        var audioInput: AVAssetWriterInput?
        if let audioTrack = audioTracks.first {
            let _ = audioTrack
            let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            aInput.expectsMediaDataInRealTime = false
            if writer.canAdd(aInput) {
                writer.add(aInput)
                audioInput = aInput
            }
        }

        // Metadata
        let metadataSpec: [String: Any] = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String:
                "mdta/\(MetadataConstants.contentIdentifierKey)",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String:
                kCMMetadataBaseDataType_UTF8
        ]
        let stillImageSpec: [String: Any] = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String:
                "mdta/\(MetadataConstants.stillImageTimeKey)",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String:
                kCMMetadataBaseDataType_SInt8
        ]

        var metadataFormatDesc: CMFormatDescription?
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [metadataSpec, stillImageSpec] as CFArray,
            formatDescriptionOut: &metadataFormatDesc
        )

        if let formatDesc = metadataFormatDesc {
            let metadataInput = AVAssetWriterInput(
                mediaType: .metadata,
                outputSettings: nil,
                sourceFormatHint: formatDesc
            )
            let metadataAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metadataInput)
            if writer.canAdd(metadataInput) {
                writer.add(metadataInput)
            }

            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            // Write metadata
            let idItem = AVMutableMetadataItem()
            idItem.key = MetadataConstants.contentIdentifierKey as NSString
            idItem.keySpace = .quickTimeMetadata
            idItem.value = contentIdentifier as NSString
            idItem.dataType = kCMMetadataBaseDataType_UTF8 as String

            let stillItem = AVMutableMetadataItem()
            stillItem.key = MetadataConstants.stillImageTimeKey as NSString
            stillItem.keySpace = .quickTimeMetadata
            stillItem.value = 0 as NSNumber
            stillItem.dataType = kCMMetadataBaseDataType_SInt8 as String

            let compositionDuration = try await composition.load(.duration)
            let metadataGroup = AVTimedMetadataGroup(
                items: [idItem, stillItem],
                timeRange: CMTimeRange(start: .zero, duration: compositionDuration)
            )
            metadataAdaptor.append(metadataGroup)
        } else {
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
        }

        // Read and write video/audio samples
        let reader = try AVAssetReader(asset: composition)

        let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
        if reader.canAdd(videoReaderOutput) {
            reader.add(videoReaderOutput)
        }

        var audioReaderOutput: AVAssetReaderTrackOutput?
        if let aTrack = audioTracks.first {
            let aOutput = AVAssetReaderTrackOutput(track: aTrack, outputSettings: nil)
            if reader.canAdd(aOutput) {
                reader.add(aOutput)
                audioReaderOutput = aOutput
            }
        }

        reader.startReading()

        // Write video samples
        await withCheckedContinuation { continuation in
            videoInput.requestMediaDataWhenReady(on: DispatchQueue(label: "video.writing")) {
                while videoInput.isReadyForMoreMediaData {
                    if let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() {
                        videoInput.append(sampleBuffer)
                    } else {
                        videoInput.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }

        // Write audio samples
        if let audioInput = audioInput, let audioReaderOutput = audioReaderOutput {
            await withCheckedContinuation { continuation in
                audioInput.requestMediaDataWhenReady(on: DispatchQueue(label: "audio.writing")) {
                    while audioInput.isReadyForMoreMediaData {
                        if let sampleBuffer = audioReaderOutput.copyNextSampleBuffer() {
                            audioInput.append(sampleBuffer)
                        } else {
                            audioInput.markAsFinished()
                            continuation.resume()
                            return
                        }
                    }
                }
            }
        }

        await writer.finishWriting()

        if writer.status != .completed {
            let message = writer.error?.localizedDescription ?? "Unknown error"
            throw V2LError.movExportFailed(message)
        }
    }

    private func videoWriterSettings(for track: AVAssetTrack) async throws -> [String: Any]? {
        // Use nil for passthrough (copy samples as-is)
        return nil
    }
}
