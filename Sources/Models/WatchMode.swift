import Foundation

enum WatchMode: String, Codable, Equatable {
    /// No monitoring.
    case off
    /// Orange border + push notification + sound.
    case on
    /// Orange border + push notification, no sound.
    case silent

    var next: WatchMode {
        switch self {
        case .off: return .on
        case .on: return .silent
        case .silent: return .off
        }
    }
}
