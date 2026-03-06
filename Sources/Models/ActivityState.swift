import Foundation

enum ActivityState: Equatable {
    case active
    case idle
    case exited(code: Int32)

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }
}
