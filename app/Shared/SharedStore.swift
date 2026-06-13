import Foundation

/// Compact task summary the phone sends to the Apple Watch (via `WatchLink`).
public struct GlanceSummary: Codable, Equatable {
    public var activeCount: Int
    public var topName: String?
    public var topSubtitle: String?
    public var updatedAt: Date

    public init(activeCount: Int, topName: String?, topSubtitle: String?, updatedAt: Date) {
        self.activeCount = activeCount
        self.topName = topName
        self.topSubtitle = topSubtitle
        self.updatedAt = updatedAt
    }
}
