import AVFoundation

private final class UnsafeSendableBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

struct MOVWriter {
    func writeMOV(
        from sourceAsset: AVURLAsset,
        timeRange: CMTimeRange,
        contentIdentifier: String,
        stillImageTime: CMTime,
        to outputURL: URL
    ) async throws {
        try Task.checkCancellation()

        let composition = try await makeComposition(from: sourceAsset, timeRange: timeRange)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let contentIdentifierItem = AVMutableMetadataItem()
        contentIdentifierItem.key = MetadataConstants.contentIdentifierKey as NSString
        contentIdentifierItem.keySpace = .quickTimeMetadata
        contentIdentifierItem.value = contentIdentifier as NSString
        contentIdentifierItem.dataType = kCMMetadataBaseDataType_UTF8 as String
        writer.metadata = [contentIdentifierItem]

        let videoTracks = try await composition.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw V2LError.movExportFailed("No video track in composition")
        }

        let videoSettings = try await makeVideoWriterSettings(for: videoTrack)
        guard writer.canApply(outputSettings: videoSettings, forMediaType: .video) else {
            throw V2LError.movExportFailed("H.264 encoding is not available for this video")
        }
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.transform = try await videoTrack.load(.preferredTransform)
        videoInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(videoInput) else {
            throw V2LError.movExportFailed("The video track cannot be written as QuickTime media")
        }
        writer.add(videoInput)

        let audioTracks = try await composition.loadTracks(withMediaType: .audio)
        var audioInput: AVAssetWriterInput?
        var audioReaderSettings: [String: Any]?
        if let audioTrack = audioTracks.first {
            let settings = try await makeAudioSettings(for: audioTrack)
            guard writer.canApply(outputSettings: settings.writer, forMediaType: .audio) else {
                throw V2LError.movExportFailed("AAC encoding is not available for this audio track")
            }
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings.writer)
            input.expectsMediaDataInRealTime = false
            guard writer.canAdd(input) else {
                throw V2LError.movExportFailed("The audio track cannot be encoded as AAC")
            }
            writer.add(input)
            audioInput = input
            audioReaderSettings = settings.reader
        }

        let metadataInput = try makeStillImageMetadataInput()
        guard writer.canAdd(metadataInput) else {
            throw V2LError.movExportFailed("The Live Photo metadata track cannot be written")
        }
        writer.add(metadataInput)
        let metadataAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metadataInput)

        let reader = try AVAssetReader(asset: composition)
        let videoOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )
        videoOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOutput) else {
            throw V2LError.unsupportedVideoEncoding
        }
        reader.add(videoOutput)

        var audioOutput: AVAssetReaderTrackOutput?
        if let audioTrack = audioTracks.first, let audioReaderSettings {
            let output = AVAssetReaderTrackOutput(
                track: audioTrack,
                outputSettings: audioReaderSettings
            )
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else {
                throw V2LError.movExportFailed("The audio track cannot be decoded")
            }
            reader.add(output)
            audioOutput = output
        }

        guard writer.startWriting() else {
            throw V2LError.movExportFailed(writer.error?.localizedDescription ?? "Failed to start writing")
        }
        writer.startSession(atSourceTime: .zero)

        let compositionDuration = try await composition.load(.duration)
        guard appendStillImageMetadata(
            with: metadataAdaptor,
            at: CMTimeClampToRange(
                stillImageTime,
                range: CMTimeRange(start: .zero, duration: compositionDuration)
            )
        ) else {
            writer.cancelWriting()
            throw V2LError.movExportFailed(writer.error?.localizedDescription ?? "Failed to write Live Photo metadata")
        }
        metadataInput.markAsFinished()

        guard reader.startReading() else {
            writer.cancelWriting()
            throw V2LError.movExportFailed(reader.error?.localizedDescription ?? "Failed to start reading media")
        }

        let cancellableReader = UnsafeSendableBox(reader)
        do {
            try await withTaskCancellationHandler {
                async let writeVideo: Void = appendSamples(
                    from: videoOutput,
                    to: videoInput,
                    reader: reader,
                    writer: writer,
                    queueLabel: "video2live.video-writing"
                )

                if let audioInput, let audioOutput {
                    async let writeAudio: Void = appendSamples(
                        from: audioOutput,
                        to: audioInput,
                        reader: reader,
                        writer: writer,
                        queueLabel: "video2live.audio-writing"
                    )
                    _ = try await (writeVideo, writeAudio)
                } else {
                    try await writeVideo
                }
            } onCancel: {
                cancellableReader.value.cancelReading()
            }
        } catch {
            reader.cancelReading()
            writer.cancelWriting()
            throw error
        }

        if Task.isCancelled {
            reader.cancelReading()
            writer.cancelWriting()
            throw CancellationError()
        }
        await writer.finishWriting()

        guard writer.status == .completed else {
            throw V2LError.movExportFailed(writer.error?.localizedDescription ?? "Failed to finish writing")
        }
    }

    private func makeVideoWriterSettings(for track: AVAssetTrack) async throws -> [String: Any] {
        let naturalSize = try await track.load(.naturalSize)
        let width = max(2, Int(abs(naturalSize.width).rounded(.down)) & ~1)
        let height = max(2, Int(abs(naturalSize.height).rounded(.down)) & ~1)
        guard width > 0, height > 0 else {
            throw V2LError.invalidVideoFile
        }

        let averageBitRate = min(max(width * height * 5, 2_000_000), 20_000_000)
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: averageBitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
    }

    private func makeAudioSettings(
        for track: AVAssetTrack
    ) async throws -> (writer: [String: Any], reader: [String: Any]) {
        let formatDescriptions = try await track.load(.formatDescriptions)
        guard let description = formatDescriptions.first,
              let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee else {
            throw V2LError.movExportFailed("The audio format could not be read")
        }

        let sampleRate = min(max(basicDescription.mSampleRate, 8_000), 96_000)
        let channelCount = min(max(Int(basicDescription.mChannelsPerFrame), 1), 2)
        let readerSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let writerSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVEncoderBitRateKey: channelCount == 1 ? 96_000 : 160_000
        ]
        return (writerSettings, readerSettings)
    }

    private func makeComposition(
        from sourceAsset: AVURLAsset,
        timeRange: CMTimeRange
    ) async throws -> AVMutableComposition {
        let sourceVideoTracks = try await sourceAsset.loadTracks(withMediaType: .video)
        guard let sourceVideoTrack = sourceVideoTracks.first else {
            throw V2LError.noVideoTrack
        }

        let sourceVideoRange = try await sourceVideoTrack.load(.timeRange)
        let videoRange = CMTimeRangeGetIntersection(timeRange, otherRange: sourceVideoRange)
        guard videoRange.isValid, !videoRange.isEmpty else {
            throw V2LError.movExportFailed("The selected range is outside the video track")
        }

        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw V2LError.movExportFailed("Failed to create the video track")
        }
        try compositionVideoTrack.insertTimeRange(videoRange, of: sourceVideoTrack, at: .zero)
        compositionVideoTrack.preferredTransform = try await sourceVideoTrack.load(.preferredTransform)

        let sourceAudioTracks = try await sourceAsset.loadTracks(withMediaType: .audio)
        if let sourceAudioTrack = sourceAudioTracks.first {
            let sourceAudioRange = try await sourceAudioTrack.load(.timeRange)
            let audioRange = CMTimeRangeGetIntersection(videoRange, otherRange: sourceAudioRange)

            if audioRange.isValid, !audioRange.isEmpty {
                guard let compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    throw V2LError.movExportFailed("Failed to create the audio track")
                }

                let insertionTime = CMTimeSubtract(audioRange.start, videoRange.start)
                try compositionAudioTrack.insertTimeRange(
                    audioRange,
                    of: sourceAudioTrack,
                    at: insertionTime
                )
            }
        }

        return composition
    }

    private func makeStillImageMetadataInput() throws -> AVAssetWriterInput {
        let metadataSpecification: [String: Any] = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String:
                "mdta/\(MetadataConstants.stillImageTimeKey)",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String:
                kCMMetadataBaseDataType_SInt8
        ]

        var formatDescription: CMFormatDescription?
        let status = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [metadataSpecification] as CFArray,
            formatDescriptionOut: &formatDescription
        )

        guard status == noErr, let formatDescription else {
            throw V2LError.movExportFailed("Failed to create the Live Photo metadata format")
        }

        return AVAssetWriterInput(
            mediaType: .metadata,
            outputSettings: nil,
            sourceFormatHint: formatDescription
        )
    }

    private func appendStillImageMetadata(
        with adaptor: AVAssetWriterInputMetadataAdaptor,
        at time: CMTime
    ) -> Bool {
        let stillImageTimeItem = AVMutableMetadataItem()
        stillImageTimeItem.key = MetadataConstants.stillImageTimeKey as NSString
        stillImageTimeItem.keySpace = .quickTimeMetadata
        stillImageTimeItem.value = 0 as NSNumber
        stillImageTimeItem.dataType = kCMMetadataBaseDataType_SInt8 as String

        let frameDuration = CMTime(value: 1, timescale: 30)
        let metadataGroup = AVTimedMetadataGroup(
            items: [stillImageTimeItem],
            timeRange: CMTimeRange(start: time, duration: frameDuration)
        )
        return adaptor.append(metadataGroup)
    }

    private func appendSamples(
        from output: AVAssetReaderOutput,
        to input: AVAssetWriterInput,
        reader: AVAssetReader,
        writer: AVAssetWriter,
        queueLabel: String
    ) async throws {
        let output = UnsafeSendableBox(output)
        let input = UnsafeSendableBox(input)
        let reader = UnsafeSendableBox(reader)
        let writer = UnsafeSendableBox(writer)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            input.value.requestMediaDataWhenReady(on: DispatchQueue(label: queueLabel)) {
                while input.value.isReadyForMoreMediaData {
                    if let sampleBuffer = output.value.copyNextSampleBuffer() {
                        guard input.value.append(sampleBuffer) else {
                            input.value.markAsFinished()
                            continuation.resume(throwing: V2LError.movExportFailed(
                                writer.value.error?.localizedDescription ?? "Failed to append media data"
                            ))
                            return
                        }
                    } else {
                        input.value.markAsFinished()

                        if reader.value.status == .failed {
                            continuation.resume(throwing: V2LError.movExportFailed(
                                reader.value.error?.localizedDescription ?? "Failed while reading media data"
                            ))
                        } else if reader.value.status == .cancelled {
                            continuation.resume(throwing: CancellationError())
                        } else {
                            continuation.resume()
                        }
                        return
                    }
                }
            }
        }
    }
}
