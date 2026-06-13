import Foundation
import CryptoKit
import GlanceCore

// Lightweight test harness — no XCTest, so it runs under Command Line Tools.
// Exits non-zero if any check fails.

var failures = 0
var count = 0

func check(_ name: String, _ condition: @autoclosure () -> Bool) {
    count += 1
    if condition() {
        print("  ✓ \(name)")
    } else {
        failures += 1
        print("  ✗ \(name)")
    }
}

func section(_ title: String) { print("\n\(title)") }

// MARK: TaskStore

section("TaskStore")
do {
    var seen: [TrackedTask] = []
    let store = TaskStore { seen.append($0) }
    store.upsert(TrackedTask(kind: .command, name: "build", state: .running))
    check("upsert emits one update", seen.count == 1 && seen.first?.name == "build")
}
do {
    let store = TaskStore(stallAfter: 1.0) { _ in }
    let t0 = Date(timeIntervalSince1970: 1_000)
    let task = TrackedTask(kind: .command, name: "train", state: .running)
    store.upsert(task, now: t0)
    let flipped = store.checkStalls(now: t0.addingTimeInterval(2))
    check("running task stalls after threshold",
          flipped == [task.id] && store.task(id: task.id)?.state == .stalled)
}
do {
    let store = TaskStore(stallAfter: 1.0) { _ in }
    let t0 = Date(timeIntervalSince1970: 1_000)
    var task = TrackedTask(kind: .command, name: "done", state: .done)
    task.finishedAt = t0
    store.upsert(task, now: t0)
    check("terminal task never stalls",
          store.checkStalls(now: t0.addingTimeInterval(99)).isEmpty)
}
do {
    let store = TaskStore(stallAfter: 10) { _ in }
    let t0 = Date(timeIntervalSince1970: 1_000)
    var task = TrackedTask(kind: .download, name: "x", state: .running,
                           progress: TaskProgress(completedUnitCount: 0))
    store.upsert(task, now: t0)
    task.progress.completedUnitCount = 500
    store.upsert(task, now: t0.addingTimeInterval(8))
    check("progress resets the stall clock",
          store.checkStalls(now: t0.addingTimeInterval(12)).isEmpty &&
          store.checkStalls(now: t0.addingTimeInterval(20)) == [task.id])
}

// MARK: CommandRunner

section("CommandRunner")
do {
    let store = TaskStore { _ in }
    let runner = try! CommandRunner(command: ["echo", "hello"])
    let final = runner.run(store: store)
    check("successful command -> done, exit 0",
          final.state == .done && final.exitCode == 0 && final.finishedAt != nil)
}
do {
    let store = TaskStore { _ in }
    let runner = try! CommandRunner(command: ["sh", "-c", "exit 3"])
    let final = runner.run(store: store)
    check("failing command -> failed, exit 3", final.state == .failed && final.exitCode == 3)
}
do {
    let store = TaskStore { _ in }
    let runner = try! CommandRunner(command: ["echo", "x"], progressPattern: "([0-9]+)%")
    let task = TrackedTask(id: "t1", kind: .command, name: "c", state: .running)
    store.upsert(task)
    runner.applyProgress(line: "Epoch 4: 42% complete", taskId: "t1", store: store)
    let updated = store.task(id: "t1")
    check("progress regex parses percent",
          updated?.progress.completedUnitCount == 42 && updated?.progress.totalUnitCount == 100)
}
do {
    var threw = false
    do { _ = try CommandRunner(command: []) } catch { threw = true }
    check("empty command throws", threw)
}

// MARK: DownloadsDetector

section("DownloadsDetector")
do {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! fm.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: dir) }

    let temp = dir.appendingPathComponent("Xcode.dmg.crdownload")
    try! Data(repeating: 0, count: 1024).write(to: temp)

    var updates: [TrackedTask] = []
    let store = TaskStore { updates.append($0) }
    let detector = DownloadsDetector(directory: dir, store: store)

    detector.poll(now: Date(timeIntervalSince1970: 100))
    let active = store.activeTasks
    let detected = active.count == 1 && active.first?.kind == .download &&
                   active.first?.name == "Xcode.dmg" && active.first?.state == .running

    try! fm.removeItem(at: temp)
    detector.poll(now: Date(timeIntervalSince1970: 105))
    check("detects in-progress download then completion",
          detected && store.activeTasks.isEmpty && updates.last?.state == .done)
}
check("displayName strips .crdownload",
      DownloadsDetector.displayName(for: URL(fileURLWithPath: "/d/Foo.zip.crdownload")) == "Foo.zip")
check("displayName strips .part",
      DownloadsDetector.displayName(for: URL(fileURLWithPath: "/d/Bar.part")) == "Bar")

// MARK: ThroughputEstimator

section("ThroughputEstimator")
do {
    var est = ThroughputEstimator(alpha: 1.0)
    let t0 = Date(timeIntervalSince1970: 0)
    _ = est.update(bytes: 0, total: 1000, now: t0)
    let (tput, eta) = est.update(bytes: 100, total: 1000, now: t0.addingTimeInterval(1))
    check("throughput = 100 B/s", abs((tput ?? 0) - 100) < 0.001)
    check("eta = 9 s", abs((eta ?? 0) - 9) < 0.001)
}

// MARK: Formatting

section("Formatting")
check("512 -> 512 B", TaskFormatter.humanBytes(512) == "512 B")
check("1536 -> 1.5 KB", TaskFormatter.humanBytes(1536) == "1.5 KB")
check("1572864 -> 1.5 MB", TaskFormatter.humanBytes(1_572_864) == "1.5 MB")

// MARK: ProcessDetector

section("ProcessDetector")
do {
    let line = "  4213 02:13 node /usr/local/bin/npm install left-pad"
    let snap = ProcessSnapshot.parse(psLine: line)
    check("parses a ps line",
          snap?.pid == 4213 && snap?.elapsed == 133 && snap?.command == "node")
}
check("etime DD-HH:MM:SS parses", ProcessSnapshot.parseETime("1-02:03:04") == 93_784)
check("etime MM:SS parses", ProcessSnapshot.parseETime("05:30") == 330)
do {
    let npm = ProcessSnapshot(pid: 1, elapsed: 10, args: ["node", "/usr/local/bin/npm", "install"])
    let rule = ProcessCatalog.rules.first { $0.test(npm) }
    check("npm install matches + names", rule?.name(for: npm) == "npm install")
}
do {
    let cargo = ProcessSnapshot(pid: 2, elapsed: 10, args: ["cargo", "build", "--release"])
    let rule = ProcessCatalog.rules.first { $0.test(cargo) }
    check("cargo build matches + names", rule?.name(for: cargo) == "cargo build")
}
do {
    let vim = ProcessSnapshot(pid: 3, elapsed: 10, args: ["vim", "notes.txt"])
    check("ordinary process is not matched", !ProcessCatalog.rules.contains { $0.test(vim) })
}
do {
    let mine = ProcessSnapshot(pid: 4, elapsed: 10, args: ["glance", "run", "--", "npm", "install"])
    check("own process tree is excluded", ProcessCatalog.isExcluded(mine))
}
do {
    var updates: [TrackedTask] = []
    let store = TaskStore { updates.append($0) }
    let detector = ProcessDetector(store: store, lister: { [] })
    let snap = ProcessSnapshot(pid: 9001, elapsed: 5, args: ["docker", "build", "."])
    detector.reconcile(snapshots: [snap], now: Date(timeIntervalSince1970: 0))
    let started = store.activeTasks.first
    detector.reconcile(snapshots: [], now: Date(timeIntervalSince1970: 5)) // pid vanished
    check("reconcile tracks then finishes a process",
          started?.name == "docker build" && started?.state == .running &&
          store.activeTasks.isEmpty && updates.last?.state == .done)
}

// MARK: Sync

section("Sync")
do {
    let env = TaskEnvelope.update(
        TrackedTask(id: "e1", kind: .download, name: "Big.dmg", state: .running,
                    progress: TaskProgress(completedUnitCount: 1024)),
        now: Date(timeIntervalSince1970: 2_000))
    let round = WireCodec.decode(WireCodec.encode(env))
    check("envelope round-trips through codec", round == env)
}
do {
    let co = SyncCoalescer(minInterval: 1.0)
    let t0 = Date(timeIntervalSince1970: 2_000)
    var task = TrackedTask(id: "a", kind: .command, name: "x", state: .running)
    let first = co.shouldSend(task, now: t0)
    let suppressed = co.shouldSend(task, now: t0.addingTimeInterval(0.1))
    task.state = .done
    let flushed = co.shouldSend(task, now: t0.addingTimeInterval(0.2))
    check("coalescer: send, suppress steady, flush on state change",
          first && !suppressed && flushed)
}
do {
    let t0 = Date(timeIntervalSince1970: 2_000)
    let transport = LoopbackTransport()
    let sub = SyncSubscriber()
    transport.onReceive = { sub.ingest($0) }
    let pub = SyncPublisher(transport: transport, coalescer: SyncCoalescer(minInterval: 0))

    var task = TrackedTask(id: "j", kind: .process, name: "build", state: .running)
    pub.publish(task, now: t0)
    let running = sub.task(id: "j")?.state == .running && sub.activeTasks.count == 1
    task.state = .done
    task.finishedAt = t0
    pub.publish(task, now: t0.addingTimeInterval(1))
    check("publisher -> subscriber end to end",
          running && sub.task(id: "j")?.state == .done && sub.activeTasks.isEmpty)
}
do {
    let sub = SyncSubscriber()
    sub.ingest(.update(TrackedTask(id: "r", kind: .command, name: "c", state: .running)))
    let had = sub.task(id: "r") != nil
    sub.ingest(TaskEnvelope(kind: .remove,
                            task: TrackedTask(id: "r", kind: .command, name: "c", state: .done),
                            sentAt: Date(timeIntervalSince1970: 2_000)))
    check("subscriber honors remove", had && sub.task(id: "r") == nil)
}

// MARK: LaunchAgent

section("LaunchAgent")
do {
    let xml = LaunchAgent.plistXML(label: "com.glance.agent",
                                   programArguments: ["/usr/local/bin/glance-bar"])
    check("plist has label", xml.contains("<string>com.glance.agent</string>"))
    check("plist has program path", xml.contains("<string>/usr/local/bin/glance-bar</string>"))
    check("plist has RunAtLoad true", xml.contains("<key>RunAtLoad</key>\n    <true/>"))
    check("install path under LaunchAgents",
          LaunchAgent.installURL().path.hasSuffix("Library/LaunchAgents/com.glance.agent.plist"))
}

// MARK: Crypto / secure wire

section("Crypto")
do {
    let key = SymmetricKey(size: .bits256)
    let codec = SecureCodec(key: key)
    let env = TaskEnvelope.update(
        TrackedTask(id: "s1", kind: .download, name: "Secret.dmg", state: .running),
        now: Date(timeIntervalSince1970: 3_000))
    var frame = codec.seal(env)
    check("sealed frame is newline-terminated", frame.last == 0x0A)
    frame.removeLast() // strip newline like the transport does
    check("frame does not leak plaintext task name",
          !(String(data: frame, encoding: .utf8) ?? "").contains("Secret.dmg"))
    check("same key opens the frame", codec.open(frame) == env)
}
do {
    let codec = SecureCodec(key: SymmetricKey(size: .bits256))
    let other = SecureCodec(key: SymmetricKey(size: .bits256))
    var frame = codec.seal(.heartbeat(now: Date(timeIntervalSince1970: 3_000)))
    frame.removeLast()
    check("wrong key cannot open (auth)", other.open(frame) == nil)
    check("garbage frame is rejected", codec.open(Data("not-base64!!".utf8)) == nil)
}
do {
    let codec = SecureCodec(key: SymmetricKey(size: .bits256), maxFrameBytes: 16)
    var frame = codec.seal(.heartbeat(now: Date(timeIntervalSince1970: 3_000)))
    frame.removeLast()
    check("oversized frame is rejected (DoS guard)", codec.open(frame) == nil)
}
do {
    let fm = FileManager.default
    let url = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("key")
    defer { try? fm.removeItem(at: url.deletingLastPathComponent()) }
    let k1 = try! GlanceCrypto.loadOrCreateKey(at: url)
    let k2 = try! GlanceCrypto.loadKey(at: url)
    let perms = (try? fm.attributesOfItem(atPath: url.path))?[.posixPermissions] as? Int
    check("key persists and reloads identically", GlanceCrypto.fingerprint(k1) == GlanceCrypto.fingerprint(k2))
    check("key file is user-only (0600)", perms == 0o600)
}

// MARK: Summary

print("\n\(count - failures)/\(count) checks passed")
exit(failures == 0 ? 0 : 1)
