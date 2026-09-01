import Foundation

enum ConversionStage: Equatable {
    case preparing
    case extractingCover
    case encodingVideo
    case validating
    case saving

    var title: String {
        switch self {
        case .preparing:
            return "Preparing…"
        case .extractingCover:
            return "Extracting cover…"
        case .encodingVideo:
            return "Encoding video…"
        case .validating:
            return "Validating Live Photo…"
        case .saving:
            return "Saving…"
        }
    }
}

enum ConversionFailureKind: Equatable {
    case analysis
    case photosPermission
    case conversion
}

enum ConversionState: Equatable {
    case idle
    case analyzing
    case ready
    case converting
    case completed
    case failed(kind: ConversionFailureKind, message: String)
}
