import Photos

struct PhotosImporter {
    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }

    func importLivePhoto(heicURL: URL, movURL: URL) async throws {
        try Task.checkCancellation()
        let status = await requestAuthorization()
        try Task.checkCancellation()
        guard status == .authorized || status == .limited else {
            throw V2LError.photosAuthorizationDenied
        }

        try Task.checkCancellation()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false

            request.addResource(with: .photo, fileURL: heicURL, options: options)
            request.addResource(with: .pairedVideo, fileURL: movURL, options: options)
        }
    }
}
