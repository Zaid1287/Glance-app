#if os(macOS)
import Foundation

/// Attaches to an existing process by PID and reports alive → exited (F3).
/// Cannot read a non-child's exit code, so completion is reported without one.
/// Liveness uses `kill(pid, 0)`, which is cheap and needs no special entitlement.
public final class ProcessWatcher: Detector {
    private let pid: pid_t
    private let pollInterval: TimeInterval
    private let store: TaskStore
    private let queue = DispatchQueue(label: "com.glance.process")
    private var timer: DispatchSourceTimer?
    private let taskId = UUID().uuidString

    public init(pid: pid_t, pollInterval: TimeInterval = 1.0, store: TaskStore) {
        self.pid = pid
        self.pollInterval = pollInterval
        self.store = store
    }

    public func start() {
        let name = Self.processName(pid: pid) ?? "pid \(pid)"
        let alive = Self.isAlive(pid)
        let initial = TrackedTask(
            id: taskId,
            kind: .process,
            name: name,
            state: alive ? .running : .done,
            finishedAt: alive ? nil : Date(),
            detail: alive ? "pid \(pid) running" : "pid \(pid) not found"
        )
        store.upsert(initial)
        guard alive else { return }

        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
        t.setEventHandler { [weak self] in self?.poll() }
        timer = t
        t.resume()
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    func poll(now: Date = Date()) {
        guard !Self.isAlive(pid) else { return }
        if var task = store.task(id: taskId) {
            task.state = .done
            task.finishedAt = now
            task.detail = "pid \(pid) exited"
            store.upsert(task, now: now)
        }
        stop()
    }

    /// Signal 0 performs error checking without sending a signal.
    static func isAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    /// One-shot name lookup via `ps`. Best effort.
    static func processName(pid: pid_t) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-p", "\(pid)", "-o", "comm="]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        guard (try? p.run()) != nil else { return nil }
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let name = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return nil }
        return (name as NSString).lastPathComponent
    }
}
#endif
