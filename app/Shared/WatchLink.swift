#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

/// Bridges the task summary from the phone to the Apple Watch. The phone calls
/// `sendSummary` on every change; the watch app sets `onSummary` to render it.
/// Uses `updateApplicationContext` (coalesced, latest-wins) — right for a
/// glanceable status that doesn't need a full history on the wrist.
public final class WatchLink: NSObject, WCSessionDelegate {
    public static let shared = WatchLink()

    public var onSummary: ((GlanceSummary) -> Void)?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    public func sendSummary(_ summary: GlanceSummary) {
        guard WCSession.isSupported(), let data = try? JSONEncoder().encode(summary) else { return }
        try? WCSession.default.updateApplicationContext(["summary": data])
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["summary"] as? Data,
              let summary = try? JSONDecoder().decode(GlanceSummary.self, from: data) else { return }
        DispatchQueue.main.async { self.onSummary?(summary) }
    }

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    #endif
}
#endif
