import Foundation

/// Thread-safe registry of tracked tasks. Every mutation emits the updated task
/// through `onUpdate` — this is the single seam the future sync client / menu
/// bar UI subscribes to. Detectors only talk to the store; they never know how
/// updates are delivered.
public final class TaskStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.glance.store")
    private var tasks: [String: TrackedTask] = [:]
    private var lastProgressAt: [String: Date] = [:]

    /// Seconds of no forward progress before a running task flips to `.stalled` (F7).
    public var stallAfter: TimeInterval

    private let onUpdate: (TrackedTask) -> Void

    public init(stallAfter: TimeInterval = 120, onUpdate: @escaping (TrackedTask) -> Void) {
        self.stallAfter = stallAfter
        self.onUpdate = onUpdate
    }

    /// Insert or update a task. Stamps `updatedAt`, tracks the last time progress
    /// actually moved (for stall detection), and emits.
    @discardableResult
    public func upsert(_ task: TrackedTask, now: Date = Date()) -> TrackedTask {
        queue.sync {
            var t = task
            t.updatedAt = now

            let prev = tasks[t.id]
            let progressMoved =
                prev == nil ||
                prev?.progress.completedUnitCount != t.progress.completedUnitCount ||
                prev?.state != t.state
            if progressMoved {
                lastProgressAt[t.id] = now
            }

            tasks[t.id] = t
            onUpdate(t)
            return t
        }
    }

    /// Promote any running task with no recent progress to `.stalled` and emit.
    /// Call this on a timer. Returns the ids that flipped.
    @discardableResult
    public func checkStalls(now: Date = Date()) -> [String] {
        queue.sync {
            var flipped: [String] = []
            for (id, task) in tasks where task.state == .running {
                let last = lastProgressAt[id] ?? task.updatedAt
                if now.timeIntervalSince(last) >= stallAfter {
                    var t = task
                    t.state = .stalled
                    t.updatedAt = now
                    tasks[id] = t
                    flipped.append(id)
                    onUpdate(t)
                }
            }
            return flipped
        }
    }

    public func task(id: String) -> TrackedTask? {
        queue.sync { tasks[id] }
    }

    public var allTasks: [TrackedTask] {
        queue.sync { Array(tasks.values) }
    }

    public var activeTasks: [TrackedTask] {
        queue.sync { tasks.values.filter { !$0.state.isTerminal } }
    }
}
