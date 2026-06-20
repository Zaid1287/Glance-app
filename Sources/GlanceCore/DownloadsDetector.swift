import Foundation

/// Watches a directory (default: ~/Downloads) for in-progress browser downloads
/// and reports each as a `.download` task with live bytes + throughput.
///
/// MVP uses polling for portability — FSEvents is the production upgrade behind
/// this same class (the rest of the system never sees the difference).
///
/// Safari's `.download` package carries an `Info.plist` with the expected total
/// and bytes-so-far, so for Safari we report a real **%**. Other browsers'
/// partials (`.crdownload`, `.part`, …) don't expose a total on disk, so they
/// stay honest bytes-downloaded + throughput rather than a fake %.
public final class DownloadsDetector: Detector {
    /// In-progress markers across the common browsers.
    /// Safari uses a `*.download` *package directory*; the rest are file suffixes.
    static let inProgressSuffixes = [
        ".crdownload",   // Chrome, Chromium, Edge, Brave
        ".part",         // Firefox
        ".partial",      // some Firefox / IDM variants
        ".opdownload",   // Opera
        ".download",     // Safari (directory)
    ]

    private let directory: URL
    private let pollInterval: TimeInterval
    private let store: TaskStore
    private let queue = DispatchQueue(label: "com.glance.downloads")
    private var timer: DispatchSourceTimer?

    /// tempPath -> (taskId, throughput estimator, last seen byte count).
    private var tracked: [String: (id: String, est: ThroughputEstimator, lastBytes: Int64)] = [:]

    public init(
        directory: URL? = nil,
        pollInterval: TimeInterval = 1.0,
        store: TaskStore
    ) {
        self.directory = directory
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        self.pollInterval = pollInterval
        self.store = store
    }

    public func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: pollInterval)
        t.setEventHandler { [weak self] in self?.poll() }
        timer = t
        t.resume()
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    /// One scan pass. Public so tests can drive it deterministically.
    public func poll(now: Date = Date()) {
        let fm = FileManager.default
        let entries = (try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let present = Set(entries.map(\.path).filter(Self.isInProgress))

        // New + ongoing downloads.
        for url in entries where Self.isInProgress(url.path) {
            let path = url.path
            // Safari exposes the expected total (-> real %); others give bytes only.
            let safari = Self.safariProgress(of: url)
            let bytes = safari?.completed ?? Self.sizeOnDisk(of: url)
            let total = safari?.total

            if tracked[path] == nil {
                let task = TrackedTask(
                    kind: .download,
                    name: Self.displayName(for: url),
                    state: .running,
                    progress: TaskProgress(completedUnitCount: bytes, totalUnitCount: total),
                    detail: "downloading"
                )
                tracked[path] = (task.id, ThroughputEstimator(), bytes)
                store.upsert(task, now: now)
            } else {
                var entry = tracked[path]!
                guard bytes != entry.lastBytes else { continue } // unchanged -> don't churn
                let (tput, eta) = entry.est.update(bytes: bytes, total: total, now: now)
                entry.lastBytes = bytes
                tracked[path] = entry
                if var task = store.task(id: entry.id) {
                    task.progress.completedUnitCount = bytes
                    task.progress.totalUnitCount = total ?? task.progress.totalUnitCount
                    task.progress.throughputBytesPerSec = tput
                    task.progress.etaSeconds = eta
                    store.upsert(task, now: now)
                }
            }
        }

        // Finished / vanished downloads: temp marker gone -> best-effort done.
        for (path, entry) in tracked where !present.contains(path) {
            if var task = store.task(id: entry.id) {
                task.state = .done
                task.finishedAt = now
                task.detail = "completed"
                store.upsert(task, now: now)
            }
            tracked[path] = nil
        }
    }

    public static func isInProgress(_ path: String) -> Bool {
        inProgressSuffixes.contains { path.hasSuffix($0) }
    }

    /// Strip the temp suffix to recover the user-facing file name.
    public static func displayName(for url: URL) -> String {
        var name = url.lastPathComponent
        for suffix in inProgressSuffixes where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
            break
        }
        return name.isEmpty ? url.lastPathComponent : name
    }

    /// For a Safari `.download` package, read the expected total + bytes-so-far
    /// from its `Info.plist` so we can report a real %. Returns nil for other
    /// browsers (no total on disk) or if the keys aren't present yet.
    public static func safariProgress(of url: URL) -> (completed: Int64, total: Int64)? {
        guard url.pathExtension == "download" else { return nil }
        let plistURL = url.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let plist = obj as? [String: Any],
              let total = (plist["DownloadEntryProgressTotalToLoad"] as? NSNumber)?.int64Value,
              total > 0
        else { return nil }
        let done = (plist["DownloadEntryProgressBytesSoFar"] as? NSNumber)?.int64Value ?? 0
        return (min(done, total), total)
    }

    /// Byte size of a file, or recursive total for a Safari `.download` package.
    public static func sizeOnDisk(of url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? Int64) ?? 0
        }
        var total: Int64 = 0
        if let en = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let f as URL in en {
                total += Int64((try? f.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            }
        }
        return total
    }
}
