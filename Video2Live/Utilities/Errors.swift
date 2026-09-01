import Foundation

enum V2LError: LocalizedError {
    case noVideoTrack
    case frameExtractionFailed
    case heicWriteFailed
    case movExportFailed(String)
    case photosAuthorizationDenied
    case photosImportFailed(String)
    case exportFailed(String)
    case validationFailed(String)
    case invalidVideoFile
    case unsupportedVideoEncoding
    case analysisError(String)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "The selected file does not contain a video track."
        case .frameExtractionFailed:
            return "Failed to extract a frame from the video."
        case .heicWriteFailed:
            return "Failed to write the HEIC image file."
        case .movExportFailed(let detail):
            return "Failed to export the MOV video: \(detail)"
        case .photosAuthorizationDenied:
            return "Photos library access was denied. Please grant permission in System Settings > Privacy & Security > Photos."
        case .photosImportFailed(let detail):
            return "Failed to import Live Photo to Photos library: \(detail)"
        case .exportFailed(let detail):
            return "Failed to export the Live Photo pair: \(detail)"
        case .validationFailed(let detail):
            return "The generated Live Photo is invalid: \(detail)"
        case .invalidVideoFile:
            return "The selected file is not a valid video."
        case .unsupportedVideoEncoding:
            return "This video uses a format or codec that AVFoundation cannot decode."
        case .analysisError(let detail):
            return "Failed to analyze video: \(detail)"
        }
    }
}
