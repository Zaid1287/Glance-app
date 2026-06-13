import Foundation

/// Renders task updates for the terminal. The phone surfaces will format their
/// own way; this is the local sink that stands in for the sync client today.
public enum TaskFormatter {
    public static func humanBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var i = 0
        while value >= 1024, i < units.count - 1 { value /= 1024; i += 1 }
        return i == 0 ? "\(bytes) B" : String(format: "%.1f %@", value, units[i])
    }

    public static func humanDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(s % 60)s" }
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }

    private static let glyph: [TaskState: String] = [
        .queued: "•", .running: "▸", .stalled: "■",
        .done: "✓", .failed: "✗", .paused: "⏸",
    ]

    /// One status line, e.g.
    /// `▸ download  Xcode_16.dmg  1.2 GB  3.4 MB/s  ETA 2m 10s`
    public static func line(for t: TrackedTask) -> String {
        var parts: [String] = [glyph[t.state] ?? "?", t.kind.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0), t.name]

        if let frac = t.progress.fraction {
            parts.append(String(format: "%.0f%%", frac * 100))
        }
        if let done = t.progress.completedUnitCount {
            parts.append(humanBytes(done))
        }
        if let tput = t.progress.throughputBytesPerSec, tput > 0 {
            parts.append("\(humanBytes(Int64(tput)))/s")
        }
        if let eta = t.progress.etaSeconds {
            parts.append("ETA \(humanDuration(eta))")
        }
        if t.state.isTerminal {
            parts.append("in \(humanDuration(t.duration))")
            if let code = t.exitCode, code != 0 { parts.append("exit \(code)") }
        }
        return parts.joined(separator: "  ")
    }

    public static func json(for t: TrackedTask) -> String {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(t), let s = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return s
    }
}
