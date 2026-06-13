import Foundation

/// Watches a single file growing toward an (optional) target size — e.g. a
/// render output, an export, a `dd` image. With a target it reports a real
/// percentage + ETA (F4); without one it reports bytes + throughput and calls
/// the task done once the size holds steady for `stabledPolls` consecutive polls.
public final class FileGrowthWatcher: Detector {
    private let url: URL
    private let target: Int64?
    private let pollInterval: TimeInterval
    private let stablePolls: Int
    private let store: TaskStore
    private let queue = DispatchQueue(label: "com.glance.filegrowth")
    private var timer: DispatchSourceTimer?

    private let taskId: String
    private var est = ThroughputEstimator()
    private var lastSize: Int64 = -1
    private var stableCount = 0

    public init(
        url: URL,
        target: Int64? = nil,
        pollInterval: TimeInterval = 1.0,
        stablePolls: Int = 3,
        store: TaskStore
    ) {
        self.url = url
        self.target = target
        self.pollInterval = pollInterval
        self.stablePolls = stablePolls
        self.store = store
        self.taskId = UUID().uuidString
    }

    public func start() {
        let initial = TrackedTask(
            id: taskId,
            kind: .fileGrowth,
            name: url.lastPathComponent,
            state: .running,
            progress: TaskProgress(totalUnitCount: target),
            detail: "watching \(url.path)"
        )
        store.upsert(initial)

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
        let size = DownloadsDetector.sizeOnDisk(of: url)
        let (tput, eta) = est.update(bytes: size, total: target, now: now)

        guard var task = store.task(id: taskId) else { return }
        task.progress.completedUnitCount = size
        task.progress.totalUnitCount = target
        task.progress.throughputBytesPerSec = tput
        task.progress.etaSeconds = eta

        // Completion: reached target, or size held steady (no target).
        if let target, size >= target {
            finish(&task, now: now)
        } else if size == lastSize {
            stableCount += 1
            if target == nil && stableCount >= stablePolls {
                finish(&task, now: now)
            } else {
                store.upsert(task, now: now)
            }
        } else {
            stableCount = 0
            store.upsert(task, now: now)
        }
        lastSize = size
    }

    private func finish(_ task: inout TrackedTask, now: Date) {
        task.state = .done
        task.finishedAt = now
        task.detail = "completed"
        store.upsert(task, now: now)
        stop()
    }
}
