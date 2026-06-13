#if os(macOS)
import Foundation

/// A snapshot of one running process. Whitespace-split argv is good enough for
/// detection (we never execute it). `command` is the basename of argv[0].
public struct ProcessSnapshot: Sendable, Equatable {
    public let pid: pid_t
    public let elapsed: TimeInterval
    public let args: [String]

    public init(pid: pid_t, elapsed: TimeInterval, args: [String]) {
        self.pid = pid
        self.elapsed = elapsed
        self.args = args
    }

    public var command: String {
        guard let first = args.first else { return "" }
        return (first as NSString).lastPathComponent
    }

    /// argv basenames — what rules match against (so `/usr/local/bin/npm` → `npm`).
    public var tokens: [String] {
        args.map { ($0 as NSString).lastPathComponent }
    }

    /// Parse one `ps -axo pid=,etime=,args=` line, e.g. `" 1234 02:13 node /p/npm install"`.
    public static func parse(psLine: String) -> ProcessSnapshot? {
        let trimmed = psLine.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count >= 3, let pid = pid_t(parts[0]) else { return nil }
        let elapsed = parseETime(String(parts[1]))
        let args = parts[2].split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !args.isEmpty else { return nil }
        return ProcessSnapshot(pid: pid, elapsed: elapsed, args: args)
    }

    /// ps etime is `[[DD-]HH:]MM:SS`.
    public static func parseETime(_ s: String) -> TimeInterval {
        var rest = s
        var days = 0.0
        if let dash = rest.firstIndex(of: "-") {
            days = Double(rest[..<dash]) ?? 0
            rest = String(rest[rest.index(after: dash)...])
        }
        var seconds = 0.0
        for comp in rest.split(separator: ":") {
            seconds = seconds * 60 + (Double(comp) ?? 0)
        }
        return days * 86_400 + seconds
    }
}

/// A pattern that recognizes a long-running task from its process snapshot.
public struct ProcessRule {
    public let label: String
    let matches: (ProcessSnapshot) -> Bool
    let display: (ProcessSnapshot) -> String

    public init(
        label: String,
        matches: @escaping (ProcessSnapshot) -> Bool,
        display: @escaping (ProcessSnapshot) -> String
    ) {
        self.label = label
        self.matches = matches
        self.display = display
    }

    public func test(_ snap: ProcessSnapshot) -> Bool { matches(snap) }
    public func name(for snap: ProcessSnapshot) -> String { display(snap) }
}

/// The built-in detector catalog. This is the moat — it grows over time, and a
/// future plugin SDK lets users extend it without an app update.
public enum ProcessCatalog {
    /// True if any argv basename is in `tools` and (when given) any token is in `subs`.
    static func tool(_ tools: Set<String>, subs: Set<String>? = nil) -> (ProcessSnapshot) -> Bool {
        { snap in
            guard snap.tokens.contains(where: tools.contains) else { return false }
            guard let subs else { return true }
            return snap.tokens.contains(where: subs.contains)
        }
    }

    /// "<tool> <sub>" display, e.g. "npm install", falling back to the tool name.
    static func name(_ tools: Set<String>, subs: Set<String>) -> (ProcessSnapshot) -> String {
        { snap in
            let t = snap.tokens.first(where: tools.contains) ?? snap.command
            if let s = snap.tokens.first(where: subs.contains) { return "\(t) \(s)" }
            return t
        }
    }

    public static let rules: [ProcessRule] = {
        let buildSubs: Set<String> = ["install", "ci", "build", "run", "test", "update", "upgrade", "compile"]
        return [
            ProcessRule(label: "node",
                        matches: tool(["npm", "yarn", "pnpm"], subs: buildSubs),
                        display: name(["npm", "yarn", "pnpm"], subs: buildSubs)),
            ProcessRule(label: "pip",
                        matches: tool(["pip", "pip3"], subs: ["install", "download", "wheel"]),
                        display: name(["pip", "pip3"], subs: ["install", "download", "wheel"])),
            ProcessRule(label: "cargo",
                        matches: tool(["cargo"], subs: ["build", "test", "run", "check", "update", "install"]),
                        display: name(["cargo"], subs: ["build", "test", "run", "check", "update", "install"])),
            ProcessRule(label: "xcodebuild",
                        matches: tool(["xcodebuild"]),
                        display: { _ in "xcodebuild" }),
            ProcessRule(label: "docker",
                        matches: tool(["docker"], subs: ["build", "pull", "push"]),
                        display: name(["docker"], subs: ["build", "pull", "push"])),
            ProcessRule(label: "brew",
                        matches: tool(["brew"], subs: ["install", "upgrade", "update", "reinstall"]),
                        display: name(["brew"], subs: ["install", "upgrade", "update", "reinstall"])),
            ProcessRule(label: "make",
                        matches: { $0.tokens.contains("make") },
                        display: { _ in "make" }),
            ProcessRule(label: "rsync",
                        matches: { $0.tokens.contains("rsync") },
                        display: { _ in "rsync" }),
            ProcessRule(label: "scp",
                        matches: { $0.tokens.contains("scp") },
                        display: { _ in "scp" }),
            ProcessRule(label: "wget",
                        matches: { $0.tokens.contains("wget") },
                        display: { _ in "wget" }),
        ]
    }()

    /// Never track our own process tree or the scanning helpers.
    static let excludedTokens: Set<String> = ["glance", "glance-selftest", "ps", "grep"]

    public static func isExcluded(_ snap: ProcessSnapshot) -> Bool {
        snap.tokens.contains(where: excludedTokens.contains)
    }
}

/// Watches the running process list and auto-tracks recognized long-running
/// tasks (builds, installs, transfers). These rarely report a percentage, so we
/// surface name + running/exited honestly rather than faking progress.
public final class ProcessDetector: Detector {
    private let store: TaskStore
    private let pollInterval: TimeInterval
    private let rules: [ProcessRule]
    private let lister: () -> [ProcessSnapshot]
    private let queue = DispatchQueue(label: "com.glance.process-detector")
    private var timer: DispatchSourceTimer?
    private var tracked: [pid_t: String] = [:]   // pid -> taskId

    public init(
        store: TaskStore,
        pollInterval: TimeInterval = 2.0,
        rules: [ProcessRule] = ProcessCatalog.rules,
        lister: @escaping () -> [ProcessSnapshot] = ProcessLister.live
    ) {
        self.store = store
        self.pollInterval = pollInterval
        self.rules = rules
        self.lister = lister
    }

    public func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: pollInterval)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            self.reconcile(snapshots: self.lister())
        }
        timer = t
        t.resume()
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Pure reconciliation against a snapshot set — start new matches, finish
    /// vanished ones. Public so tests can drive it without spawning processes.
    public func reconcile(snapshots: [ProcessSnapshot], now: Date = Date()) {
        let livePids = Set(snapshots.map(\.pid))

        for snap in snapshots where tracked[snap.pid] == nil {
            guard !ProcessCatalog.isExcluded(snap),
                  let rule = rules.first(where: { $0.test(snap) }) else { continue }
            let task = TrackedTask(
                kind: .process,
                name: rule.name(for: snap),
                state: .running,
                detail: "pid \(snap.pid) · \(rule.label)"
            )
            tracked[snap.pid] = task.id
            store.upsert(task, now: now)
        }

        for (pid, id) in tracked where !livePids.contains(pid) {
            if var task = store.task(id: id) {
                task.state = .done
                task.finishedAt = now
                task.detail = "exited"
                store.upsert(task, now: now)
            }
            tracked[pid] = nil
        }
    }
}

/// Live process list via `ps`. Best effort; returns [] on failure.
public enum ProcessLister {
    public static func live() -> [ProcessSnapshot] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-axo", "pid=,etime=,args="]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        guard (try? p.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let out = String(data: data, encoding: .utf8) ?? ""
        return out.split(separator: "\n").compactMap { ProcessSnapshot.parse(psLine: String($0)) }
    }
}
#endif
