import AVFoundation
import ImageIO

struct LivePhotoValidator {
    func validate(
        heicURL: URL,
        movURL: URL,
        expectedContentIdentifier: String,
        expectedDuration: CMTime,
        expectedStillImageTime: CMTime
    ) async throws {
        try validateFile(at: heicURL, label: "HEIC")
        try validateFile(at: movURL, label: "MOV")
        try validateImageIdentifier(
            at: heicURL,
            expectedContentIdentifier: expectedContentIdentifier
        )

        let asset = AVURLAsset(url: movURL)
        try await validateVideoTrack(in: asset)
        try await validateDuration(asset, expectedDuration: expectedDuration)
        try await validateMovieIdentifier(
            in: asset,
            expectedContentIdentifier: expectedContentIdentifier
        )
        try await validateStillImageTime(
            in: asset,
            expectedStillImageTime: expectedStillImageTime
        )
    }

    private func validateFile(at url: URL, label: String) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, (values.fileSize ?? 0) > 0 else {
            throw V2LError.validationFailed("The \(label) file is empty or missing")
        }
    }

    private func validateImageIdentifier(
        at url: URL,
        expectedContentIdentifier: String
    ) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let makerApple = properties[kCGImagePropertyMakerAppleDictionary]
                as? [String: Any],
              let identifier = makerApple[MetadataConstants.makerAppleAssetIdentifierKey]
                as? String,
              identifier == expectedContentIdentifier else {
            throw V2LError.validationFailed("The HEIC pairing identifier is missing or incorrect")
        }
    }

    private func validateVideoTrack(in asset: AVURLAsset) async throws {
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else {
            throw V2LError.validationFailed("The MOV has no video track")
        }

        let descriptions = try await track.load(.formatDescriptions)
        guard let description = descriptions.first,
              CMFormatDescriptionGetMediaSubType(description) == kCMVideoCodecType_H264 else {
            throw V2LError.validationFailed("The MOV video is not encoded as H.264")
        }
    }

    private func validateDuration(_ asset: AVURLAsset, expectedDuration: CMTime) async throws {
        let duration = try await asset.load(.duration)
        let actualSeconds = duration.seconds
        let expectedSeconds = expectedDuration.seconds
        guard actualSeconds.isFinite,
              expectedSeconds.isFinite,
              abs(actualSeconds - expectedSeconds) <= 0.1 else {
            throw V2LError.validationFailed("The MOV duration does not match the selected clip")
        }
    }

    private func validateMovieIdentifier(
        in asset: AVURLAsset,
        expectedContentIdentifier: String
    ) async throws {
        let metadata = try await asset.load(.metadata)
        let items = AVMetadataItem.metadataItems(
            from: metadata,
            withKey: MetadataConstants.contentIdentifierKey as NSString,
            keySpace: .quickTimeMetadata
        )
        guard let item = items.first,
              try await item.load(.stringValue) == expectedContentIdentifier else {
            throw V2LError.validationFailed("The MOV pairing identifier is missing or incorrect")
        }
    }

    private func validateStillImageTime(
        in asset: AVURLAsset,
        expectedStillImageTime: CMTime
    ) async throws {
        let tracks = try await asset.loadTracks(withMediaType: .metadata)

        for track in tracks {
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            guard reader.canAdd(output) else { continue }
            reader.add(output)
            let adaptor = AVAssetReaderOutputMetadataAdaptor(assetReaderTrackOutput: output)
            guard reader.startReading() else { continue }

            while let group = adaptor.nextTimedMetadataGroup() {
                let items = AVMetadataItem.metadataItems(
                    from: group.items,
                    withKey: MetadataConstants.stillImageTimeKey as NSString,
                    keySpace: .quickTimeMetadata
                )
                guard let item = items.first,
                      try await item.load(.numberValue)?.intValue == 0 else {
                    continue
                }

                let difference = abs(group.timeRange.start.seconds - expectedStillImageTime.seconds)
                guard difference <= 1.0 / 15.0 else {
                    throw V2LError.validationFailed("The MOV cover-frame time is incorrect")
                }
                return
            }
        }

        throw V2LError.validationFailed("The MOV cover-frame metadata is missing")
    }
}