import SwiftUI

@main
struct GlanceWatchApp: App {
    @StateObject private var model = WatchModel()
    var body: some Scene {
        WindowGroup {
            WatchContentView().environmentObject(model)
        }
    }
}

@MainActor
final class WatchModel: ObservableObject {
    @Published var summary: GlanceSummary?

    init() {
        WatchLink.shared.onSummary = { [weak self] summary in
            self?.summary = summary
        }
    }
}

struct WatchContentView: View {
    @EnvironmentObject private var model: WatchModel

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.title3)
            if let s = model.summary, s.activeCount > 0 {
                Text(s.topName ?? "Task").font(.headline).lineLimit(2).multilineTextAlignment(.center)
                if let sub = s.topSubtitle, !sub.isEmpty {
                    Text(sub).font(.caption2).foregroundStyle(.secondary)
                }
                if s.activeCount > 1 {
                    Text("+\(s.activeCount - 1) more").font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text("No active tasks").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
