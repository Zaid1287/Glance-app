import Foundation

/// A source of tracked tasks. Detectors push tasks into a `TaskStore`; they do
/// not deliver updates themselves. New detectors (Homebrew, docker, rsync, …)
/// conform to this — the catalog is meant to grow behind this seam.
public protocol Detector: AnyObject {
    /// Begin watching. Non-blocking: schedules work on a timer/run loop.
    func start()
    /// Stop watching and release resources.
    func stop()
}

/// Exponentially-weighted moving average of throughput (bytes/sec) plus a
/// straight-line ETA. Smoothing keeps the phone-side number from jumping (N5).
public struct ThroughputEstimator {
    private var lastBytes: Int64?
    private var lastAt: Date?
    private var ewmaBytesPerSec: Double?
    private let alpha: Double

    public init(alpha: Double = 0.3) {
        self.alpha = alpha
    }

    /// Feed a new cumulative byte count. Returns (throughput, eta) where eta is
    /// nil unless a positive `total` is supplied and throughput is positive.
    public mutating func update(
        bytes: Int64,
        total: Int64?,
        now: Date = Date()
    ) -> (throughput: Double?, eta: Double?) {
        defer { lastBytes = bytes; lastAt = now }
        guard let lb = lastBytes, let la = lastAt else {
            return (nil, nil)
        }
        let dt = now.timeIntervalSince(la)
        guard dt > 0 else { return (ewmaBytesPerSec, nil) }

        let instant = Double(bytes - lb) / dt
        let smoothed: Double
        if let prev = ewmaBytesPerSec {
            smoothed = alpha * instant + (1 - alpha) * prev
        } else {
            smoothed = instant
        }
        ewmaBytesPerSec = smoothed

        var eta: Double?
        if let total, total > bytes, smoothed > 1 {
            eta = Double(total - bytes) / smoothed
        }
        return (smoothed, eta)
    }
}
