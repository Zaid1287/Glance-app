import Foundation

/// The kind of work a tracked task represents.
public enum TaskKind: String, Codable, Sendable {
    case download      // browser / file download in progress
    case command       // `glance run -- ...` wrapped shell command
    case process       // attached to an existing PID
    case fileGrowth    // a file growing toward a target size
}

/// Lifecycle state machine: queued → running → (stalled) → done | failed | paused.
public enum TaskState: String, Codable, Sendable {
    case queued
    case running
    case stalled       // running but no progress for `stallAfter` seconds
    case done
    case failed
    case paused        // e.g. Mac asleep

    /// States that mean the task will not change further on its own.
    public var isTerminal: Bool {
        self == .done || self == .failed
    }
}

/// Progress snapshot. All byte/fraction fields are optional because many real
/// tasks (browser downloads without a Content-Length, unbounded scripts) cannot
/// report a total. ETA/throughput are derived, not stored at source.
public struct TaskProgress: Codable, Sendable, Equatable {
    public var completedUnitCount: Int64?
    public var totalUnitCount: Int64?
    public var throughputBytesPerSec: Double?
    public var etaSeconds: Double?

    public init(
        completedUnitCount: Int64? = nil,
        totalUnitCount: Int64? = nil,
        throughputBytesPerSec: Double? = nil,
        etaSeconds: Double? = nil
    ) {
        self.completedUnitCount = completedUnitCount
        self.totalUnitCount = totalUnitCount
        self.throughputBytesPerSec = throughputBytesPerSec
        self.etaSeconds = etaSeconds
    }

    /// 0...1 when both completed and total are known, else nil.
    public var fraction: Double? {
        guard let c = completedUnitCount, let t = totalUnitCount, t > 0 else { return nil }
        return min(1.0, max(0.0, Double(c) / Double(t)))
    }
}

/// The canonical task model the agent tracks and (later) syncs to the phone.
/// Only metadata lives here — never file contents or command output (N3).
public struct TrackedTask: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var kind: TaskKind
    public var name: String
    public var state: TaskState
    public var progress: TaskProgress
    public let createdAt: Date
    public var updatedAt: Date
    public var finishedAt: Date?
    public var exitCode: Int32?
    public var detail: String?

    public init(
        id: String = UUID().uuidString,
        kind: TaskKind,
        name: String,
        state: TaskState = .queued,
        progress: TaskProgress = TaskProgress(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        finishedAt: Date? = nil,
        exitCode: Int32? = nil,
        detail: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.state = state
        self.progress = progress
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.finishedAt = finishedAt
        self.exitCode = exitCode
        self.detail = detail
    }

    /// Wall-clock runtime so far (or total, if finished).
    public var duration: TimeInterval {
        (finishedAt ?? updatedAt).timeIntervalSince(createdAt)
    }
}
