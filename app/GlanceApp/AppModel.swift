import Foundation
import SwiftUI
import ActivityKit
import WidgetKit
import CryptoKit
import GlanceCore
#if canImport(UIKit)
import UIKit
#endif

/// App brain: receives encrypted task updates over the LAN, mirrors them into a
/// `SyncSubscriber`, drives one Live Activity per active task, and publishes the
/// list for the UI. The transport is `MultipeerBrowser` (zero-config); the same
/// seam accepts a push-relay transport later with no change here.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var tasks: [TrackedTask] = []
    @Published private(set) var hasKey: Bool
    @Published private(set) var keyFingerprint: String?

    private let subscriber = SyncSubscriber()
    private var browser: MultipeerBrowser?
    private var activities: [String: Activity<GlanceActivityAttributes>] = [:]
    private var firedDone: Set<String> = []   // tasks that already buzzed/notified

    init() {
        let key = try? PairingKeyStore.load()
        hasKey = key != nil
        keyFingerprint = key.map(GlanceCrypto.fingerprint)
        Notifier.requestAuthorization()
    }

    /// Begin browsing for the paired Mac. No-op until a key exists.
    func start() {
        guard browser == nil, let key = try? PairingKeyStore.load() else { return }
        let codec = SecureCodec(key: key)
        let b = MultipeerBrowser(displayName: Self.deviceName(), codec: codec)
        b.onReceive = { [weak self] envelope in
            Task { @MainActor in self?.ingest(envelope) }
        }
        b.start()
        browser = b
    }

    /// Store a pairing key (from QR / paste) and start syncing.
    func pair(base64Key: String) throws {
        let key = try PairingKeyStore.save(base64: base64Key)
        hasKey = true
        keyFingerprint = GlanceCrypto.fingerprint(key)
        start()
    }

    func unpair() {
        browser?.stop()
        browser = nil
        try? PairingKeyStore.delete()
        hasKey = false
        keyFingerprint = nil
        tasks = []
    }

    var activeTasks: [TrackedTask] { tasks.filter { !$0.state.isTerminal } }
    var recentTasks: [TrackedTask] { tasks.filter { $0.state.isTerminal } }

    // MARK: - Ingest + Live Activities

    private func ingest(_ envelope: TaskEnvelope) {
        subscriber.ingest(envelope)
        tasks = subscriber.snapshot.sorted {
            ($0.finishedAt ?? .distantFuture) > ($1.finishedAt ?? .distantFuture)
        }
        publishWidgetSummary()
        if let task = envelope.task {
            Task { await syncActivity(task) }
        }
    }

    private func publishWidgetSummary() {
        let active = activeTasks
        let top = active.first
        let summary = GlanceSummary(
            activeCount: active.count,
            topName: top?.name,
            topSubtitle: top.map { GlanceFormat.subtitle(.init(from: $0)) },
            updatedAt: Date())
        SharedStore.write(summary)
        WidgetCenter.shared.reloadAllTimelines()
        WatchLink.shared.sendSummary(summary)
    }

    private func syncActivity(_ task: TrackedTask) async {
        let cs = GlanceActivityAttributes.ContentState(from: task)

        // Buzz + notify once, the first time a task reaches a terminal state.
        if cs.isTerminal, !firedDone.contains(task.id) {
            firedDone.insert(task.id)
            Haptics.taskFinished(success: task.state == .done)
            Notifier.taskFinished(task)
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: cs, staleDate: Date().addingTimeInterval(60 * 30))

        if let activity = activities[task.id] {
            if cs.isTerminal {
                // Uber-Eats style: show the Done state and keep it on the Lock
                // Screen — `.default` lets the system hold it (~4h / until the
                // user swipes it away) instead of dismissing immediately.
                await activity.end(content, dismissalPolicy: .default)
                activities[task.id] = nil
            } else {
                await activity.update(content)
            }
        } else if !cs.isTerminal {
            let attrs = GlanceActivityAttributes(taskId: task.id, kind: task.kind.rawValue)
            // pushType nil = locally driven (LAN). Remote/away path would pass .token.
            if let activity = try? Activity.request(attributes: attrs, content: content, pushType: nil) {
                activities[task.id] = activity
            }
        }
    }

    private static func deviceName() -> String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "Glance"
        #endif
    }
}

/// Stores the 256-bit pairing key in the app container with at-rest file
/// protection. TODO (release hardening): migrate to the Keychain with
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
enum PairingKeyStore {
    enum StoreError: Error { case badKey }

    private static func url() throws -> URL {
        let dir = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        return dir.appendingPathComponent("glance.key")
    }

    @discardableResult
    static func save(base64: String) throws -> SymmetricKey {
        let trimmed = base64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw = Data(base64Encoded: trimmed), raw.count == 32 else { throw StoreError.badKey }
        try raw.base64EncodedString().data(using: .utf8)!
            .write(to: try url(), options: [.atomic, .completeFileProtection])
        return SymmetricKey(data: raw)
    }

    static func load() throws -> SymmetricKey {
        let data = try Data(contentsOf: try url())
        guard let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              let raw = Data(base64Encoded: text), raw.count == 32 else { throw StoreError.badKey }
        return SymmetricKey(data: raw)
    }

    static func delete() throws {
        try? FileManager.default.removeItem(at: try url())
    }
}
