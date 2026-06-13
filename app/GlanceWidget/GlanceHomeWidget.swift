import WidgetKit
import SwiftUI

/// Home / Lock Screen widget summarizing active tasks, read from the App Group
/// summary the app writes (`SharedStore`). Small + medium families.
struct GlanceHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GlanceHomeWidget", provider: GlanceProvider()) { entry in
            GlanceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Glance")
        .description("Active tasks running on your Mac.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct GlanceEntry: TimelineEntry {
    let date: Date
    let summary: GlanceSummary?
}

struct GlanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlanceEntry {
        GlanceEntry(date: Date(), summary: GlanceSummary(activeCount: 1, topName: "Xcode.dmg", topSubtitle: "42% · 3.4 MB/s", updatedAt: Date()))
    }
    func getSnapshot(in context: Context, completion: @escaping (GlanceEntry) -> Void) {
        completion(GlanceEntry(date: Date(), summary: SharedStore.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GlanceEntry>) -> Void) {
        let entry = GlanceEntry(date: Date(), summary: SharedStore.read())
        // The app pushes reloads on change; this is just a slow safety refresh.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 15))))
    }
}

struct GlanceWidgetView: View {
    let entry: GlanceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                Text("Glance").font(.caption).bold()
                Spacer()
                if let n = entry.summary?.activeCount, n > 0 {
                    Text("\(n)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let s = entry.summary, s.activeCount > 0, let name = s.topName {
                Text(name).font(.headline).lineLimit(1)
                if let sub = s.topSubtitle, !sub.isEmpty {
                    Text(sub).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                Text("No active tasks").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
