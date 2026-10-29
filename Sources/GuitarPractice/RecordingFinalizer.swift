import Foundation

/// All stop/replay/quit callers join the same save, even after capture is off.
@MainActor
final class RecordingFinalizer {
    private var pending: Task<Void, Never>?
    var isRunning: Bool { pending != nil }

    func begin(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        if let pending { return pending }
        let task = Task { [self] in
            await operation()
            pending = nil
        }
        pending = task
        return task
    }
    func wait() async { await pending?.value }
}
