import Foundation

enum ConversionState: Equatable {
    case idle
    case analyzing
    case ready
    case converting(progress: Double)
    case completed
    case failed(message: String)

    static func == (lhs: ConversionState, rhs: ConversionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.analyzing, .analyzing),
             (.ready, .ready),
             (.completed, .completed):
            return true
        case (.converting(let a), .converting(let b)):
            return a == b
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}
