import Foundation

/// Compact summary the app writes to a shared App Group so the Home Screen
/// widget (a separate process) can render without its own network access.
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

public enum SharedStore {
    /// Set this to your real App Group id in the entitlements + `project.yml`.
    public static let appGroup = "group.app.glance"
    private static let key = "glance.summary"

    public static func write(_ summary: GlanceSummary) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(summary) else { return }
        defaults.set(data, forKey: key)
    }

    public static func read() -> GlanceSummary? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GlanceSummary.self, from: data)
    }
}
