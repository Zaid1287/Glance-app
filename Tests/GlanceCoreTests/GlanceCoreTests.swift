#if canImport(XCTest)
import XCTest
import CryptoKit
@testable import GlanceCore

final class TaskStoreTests: XCTestCase {
    func testUpsertEmitsUpdate() {
        var seen: [TrackedTask] = []
        let store = TaskStore { seen.append($0) }
        store.upsert(TrackedTask(kind: .command, name: "build", state: .running))
        XCTAssertEqual(seen.count, 1)
        XCTAssertEqual(seen.first?.name, "build")
        XCTAssertEqual(seen.first?.state, .running)
    }

    func testRunningTaskGoesStaleAfterThreshold() {
        var seen: [TrackedTask] = []
        let store = TaskStore(stallAfter: 1.0) { seen.append($0) }
        let t0 = Date(timeIntervalSince1970: 1_000)
        let task = TrackedTask(kind: .command, name: "train", state: .running)
        store.upsert(task, now: t0)

        let flipped = store.checkStalls(now: t0.addingTimeInterval(2))
        XCTAssertEqual(flipped, [task.id])
        XCTAssertEqual(store.task(id: task.id)?.state, .stalled)
    }

    func testTerminalTaskNeverStalls() {
        let store = TaskStore(stallAfter: 1.0) { _ in }
        let t0 = Date(timeIntervalSince1970: 1_000)
        var task = TrackedTask(kind: .command, name: "done", state: .done)
        task.finishedAt = t0
        store.upsert(task, now: t0)
        XCTAssertTrue(store.checkStalls(now: t0.addingTimeInterval(99)).isEmpty)
    }

    func testProgressResetsStallClock() {
        let store = TaskStore(stallAfter: 10) { _ in }
        let t0 = Date(timeIntervalSince1970: 1_000)
        var task = TrackedTask(kind: .download, name: "x", state: .running,
                               progress: TaskProgress(completedUnitCount: 0))
        store.upsert(task, now: t0)
        // Progress moves at t0+8 -> clock resets, so t0+12 is not yet stale.
        task.progress.completedUnitCount = 500
        store.upsert(task, now: t0.addingTimeInterval(8))
        XCTAssertTrue(store.checkStalls(now: t0.addingTimeInterval(12)).isEmpty)
        // ...but t0+20 (12s since last progress) is.
        XCTAssertEqual(store.checkStalls(now: t0.addingTimeInterval(20)), [task.id])
    }
}

final class CommandRunnerTests: XCTestCase {
    func testSuccessfulCommandFinishesDone() throws {
        let store = TaskStore { _ in }
        let runner = try CommandRunner(command: ["echo", "hello"])
        let final = runner.run(store: store)
        XCTAssertEqual(final.state, .done)
        XCTAssertEqual(final.exitCode, 0)
        XCTAssertNotNil(final.finishedAt)
    }

    func testFailingCommandReportsExitCode() throws {
        let store = TaskStore { _ in }
        let runner = try CommandRunner(command: ["sh", "-c", "exit 3"])
        let final = runner.run(store: store)
        XCTAssertEqual(final.state, .failed)
        XCTAssertEqual(final.exitCode, 3)
    }

    func testProgressRegexParsesPercent() throws {
        let store = TaskStore { _ in }
        let runner = try CommandRunner(command: ["echo", "x"], progressPattern: "([0-9]+)%")
        var task = TrackedTask(id: "t1", kind: .command, name: "c", state: .running)
        store.upsert(task)
        runner.applyProgress(line: "Epoch 4: 42% complete", taskId: "t1", store: store)
        task = try XCTUnwrap(store.task(id: "t1"))
        XCTAssertEqual(task.progress.completedUnitCount, 42)
        XCTAssertEqual(task.progress.totalUnitCount, 100)
        XCTAssertEqual(task.progress.fraction, 0.42, accuracy: 0.001)
    }

    func testEmptyCommandThrows() {
        XCTAssertThrowsError(try CommandRunner(command: []))
    }
}

final class DownloadsDetectorTests: XCTestCase {
    func testDetectsInProgressDownloadThenCompletion() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let temp = dir.appendingPathComponent("Xcode.dmg.crdownload")
        try Data(repeating: 0, count: 1024).write(to: temp)

        var updates: [TrackedTask] = []
        let store = TaskStore { updates.append($0) }
        let detector = DownloadsDetector(directory: dir, store: store)

        detector.poll(now: Date(timeIntervalSince1970: 100))
        let active = store.activeTasks
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.kind, .download)
        XCTAssertEqual(active.first?.name, "Xcode.dmg")
        XCTAssertEqual(active.first?.state, .running)

        // Temp marker disappears (download finished) -> task done.
        try fm.removeItem(at: temp)
        detector.poll(now: Date(timeIntervalSince1970: 105))
        XCTAssertTrue(store.activeTasks.isEmpty)
        XCTAssertEqual(updates.last?.state, .done)
    }

    func testDisplayNameStripsSuffix() {
        XCTAssertEqual(
            DownloadsDetector.displayName(for: URL(fileURLWithPath: "/d/Foo.zip.crdownload")),
            "Foo.zip"
        )
        XCTAssertEqual(
            DownloadsDetector.displayName(for: URL(fileURLWithPath: "/d/Bar.part")),
            "Bar"
        )
    }
}

final class ThroughputEstimatorTests: XCTestCase {
    func testComputesThroughputAndEta() {
        var est = ThroughputEstimator(alpha: 1.0) // no smoothing -> exact
        let t0 = Date(timeIntervalSince1970: 0)
        _ = est.update(bytes: 0, total: 1000, now: t0)
        let (tput, eta) = est.update(bytes: 100, total: 1000, now: t0.addingTimeInterval(1))
        XCTAssertEqual(tput ?? 0, 100, accuracy: 0.001)            // 100 B/s
        XCTAssertEqual(eta ?? 0, 9, accuracy: 0.001)              // 900 B left / 100 = 9s
    }
}

final class FormattingTests: XCTestCase {
    func testHumanBytes() {
        XCTAssertEqual(TaskFormatter.humanBytes(512), "512 B")
        XCTAssertEqual(TaskFormatter.humanBytes(1536), "1.5 KB")
        XCTAssertEqual(TaskFormatter.humanBytes(1_572_864), "1.5 MB")
    }
}

final class ProcessDetectorTests: XCTestCase {
    func testParsePsLine() {
        let snap = ProcessSnapshot.parse(psLine: "  4213 02:13 node /usr/local/bin/npm install")
        XCTAssertEqual(snap?.pid, 4213)
        XCTAssertEqual(snap?.elapsed, 133)
        XCTAssertEqual(snap?.command, "node")
    }

    func testETimeFormats() {
        XCTAssertEqual(ProcessSnapshot.parseETime("1-02:03:04"), 93_784)
        XCTAssertEqual(ProcessSnapshot.parseETime("05:30"), 330)
    }

    func testCatalogMatchesAndNames() {
        let npm = ProcessSnapshot(pid: 1, elapsed: 10, args: ["node", "/usr/local/bin/npm", "install"])
        XCTAssertEqual(ProcessCatalog.rules.first { $0.test(npm) }?.name(for: npm), "npm install")
        let vim = ProcessSnapshot(pid: 2, elapsed: 10, args: ["vim", "notes.txt"])
        XCTAssertFalse(ProcessCatalog.rules.contains { $0.test(vim) })
    }

    func testExclusionOfOwnProcess() {
        let mine = ProcessSnapshot(pid: 3, elapsed: 10, args: ["glance", "run", "--", "npm", "install"])
        XCTAssertTrue(ProcessCatalog.isExcluded(mine))
    }

    func testReconcileTracksThenFinishes() {
        var updates: [TrackedTask] = []
        let store = TaskStore { updates.append($0) }
        let detector = ProcessDetector(store: store, lister: { [] })
        let snap = ProcessSnapshot(pid: 9001, elapsed: 5, args: ["docker", "build", "."])
        detector.reconcile(snapshots: [snap], now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(store.activeTasks.first?.name, "docker build")
        detector.reconcile(snapshots: [], now: Date(timeIntervalSince1970: 5))
        XCTAssertTrue(store.activeTasks.isEmpty)
        XCTAssertEqual(updates.last?.state, .done)
    }
}

final class SyncTests: XCTestCase {
    func testEnvelopeRoundTrip() {
        let env = TaskEnvelope.update(
            TrackedTask(id: "e1", kind: .download, name: "Big.dmg", state: .running),
            now: Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(WireCodec.decode(WireCodec.encode(env)), env)
    }

    func testCoalescerBudget() {
        let co = SyncCoalescer(minInterval: 1.0)
        let t0 = Date(timeIntervalSince1970: 2_000)
        var task = TrackedTask(id: "a", kind: .command, name: "x", state: .running)
        XCTAssertTrue(co.shouldSend(task, now: t0))
        XCTAssertFalse(co.shouldSend(task, now: t0.addingTimeInterval(0.1)))
        task.state = .done
        XCTAssertTrue(co.shouldSend(task, now: t0.addingTimeInterval(0.2)))
    }

    func testPublisherToSubscriber() {
        let t0 = Date(timeIntervalSince1970: 2_000)
        let transport = LoopbackTransport()
        let sub = SyncSubscriber()
        transport.onReceive = { sub.ingest($0) }
        let pub = SyncPublisher(transport: transport, coalescer: SyncCoalescer(minInterval: 0))
        var task = TrackedTask(id: "j", kind: .process, name: "build", state: .running)
        pub.publish(task, now: t0)
        XCTAssertEqual(sub.task(id: "j")?.state, .running)
        task.state = .done
        pub.publish(task, now: t0.addingTimeInterval(1))
        XCTAssertEqual(sub.task(id: "j")?.state, .done)
        XCTAssertTrue(sub.activeTasks.isEmpty)
    }
}

final class CryptoTests: XCTestCase {
    func testSealOpenRoundTrip() {
        let codec = SecureCodec(key: SymmetricKey(size: .bits256))
        let env = TaskEnvelope.update(
            TrackedTask(id: "s1", kind: .download, name: "Secret.dmg", state: .running),
            now: Date(timeIntervalSince1970: 3_000))
        var frame = codec.seal(env)
        frame.removeLast()
        XCTAssertFalse((String(data: frame, encoding: .utf8) ?? "").contains("Secret.dmg"))
        XCTAssertEqual(codec.open(frame), env)
    }

    func testWrongKeyAndGarbageRejected() {
        let codec = SecureCodec(key: SymmetricKey(size: .bits256))
        let other = SecureCodec(key: SymmetricKey(size: .bits256))
        var frame = codec.seal(.heartbeat(now: Date(timeIntervalSince1970: 3_000)))
        frame.removeLast()
        XCTAssertNil(other.open(frame))
        XCTAssertNil(codec.open(Data("not-base64!!".utf8)))
    }

    func testOversizedFrameRejected() {
        let codec = SecureCodec(key: SymmetricKey(size: .bits256), maxFrameBytes: 16)
        var frame = codec.seal(.heartbeat(now: Date(timeIntervalSince1970: 3_000)))
        frame.removeLast()
        XCTAssertNil(codec.open(frame))
    }

    func testKeyPersistenceAndPermissions() throws {
        let fm = FileManager.default
        let url = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("key")
        defer { try? fm.removeItem(at: url.deletingLastPathComponent()) }
        let k1 = try GlanceCrypto.loadOrCreateKey(at: url)
        let k2 = try GlanceCrypto.loadKey(at: url)
        XCTAssertEqual(GlanceCrypto.fingerprint(k1), GlanceCrypto.fingerprint(k2))
        let perms = (try? fm.attributesOfItem(atPath: url.path))?[.posixPermissions] as? Int
        XCTAssertEqual(perms, 0o600)
    }
}
#endif
