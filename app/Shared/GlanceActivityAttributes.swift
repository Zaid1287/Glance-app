import Foundation
import ActivityKit
import GlanceCore

/// Live Activity descriptor for one tracked task. The static part identifies the
/// task; `ContentState` is the part ActivityKit re-renders as progress changes.
/// Mirrors `GlanceCore.TrackedTask` so the app can map straight from a synced task.
public struct GlanceActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var state: String            // TaskState.rawValue
        public var name: String
        public var detail: String?
        public var completedUnitCount: Int64?
        public var totalUnitCount: Int64?
        public var throughputBytesPerSec: Double?
        public var etaSeconds: Double?

        public var isTerminal: Bool { state == "done" || state == "failed" }

        /// 0...1 when both bounds are known, else nil (honest: no fake bar).
        public var fraction: Double? {
            guard let c = completedUnitCount, let t = totalUnitCount, t > 0 else { return nil }
            return min(1, max(0, Double(c) / Double(t)))
        }

        public init(from task: TrackedTask) {
            state = task.state.rawValue
            name = task.name
            detail = task.detail
            completedUnitCount = task.progress.completedUnitCount
            totalUnitCount = task.progress.totalUnitCount
            throughputBytesPerSec = task.progress.throughputBytesPerSec
            etaSeconds = task.progress.etaSeconds
        }
    }

    public var taskId: String
    public var kind: String

    public init(taskId: String, kind: String) {
        self.taskId = taskId
        self.kind = kind
    }
}

/// Shared formatting so the app, widget, and Live Activity read identically.
public enum GlanceFormat {
    public static func bytes(_ n: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var v = Double(n), i = 0
        while v >= 1024, i < units.count - 1 { v /= 1024; i += 1 }
        return i == 0 ? "\(n) B" : String(format: "%.1f %@", v, units[i])
    }

    public static func duration(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(s % 60)s" }
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }

    public static func subtitle(_ cs: GlanceActivityAttributes.ContentState) -> String {
        var parts: [String] = []
        if let f = cs.fraction { parts.append(String(format: "%.0f%%", f * 100)) }
        else if let c = cs.completedUnitCount { parts.append(bytes(c)) }
        if let tp = cs.throughputBytesPerSec, tp > 0 { parts.append("\(bytes(Int64(tp)))/s") }
        if let eta = cs.etaSeconds { parts.append("ETA \(duration(eta))") }
        return parts.joined(separator: " · ")
    }
}
