import SwiftUI
import GlanceCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                if model.activeTasks.isEmpty {
                    ContentUnavailableView(
                        "No active tasks",
                        systemImage: "gauge.with.dots.needle.bottom.50percent",
                        description: Text("Tasks running on your Mac show up here."))
                } else {
                    Section("Active") {
                        ForEach(model.activeTasks) { TaskRow(task: $0) }
                    }
                }
                if !model.recentTasks.isEmpty {
                    Section("Recent") {
                        ForEach(model.recentTasks.prefix(20)) { TaskRow(task: $0) }
                    }
                }
            }
            .navigationTitle("Glance")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let fp = model.keyFingerprint {
                            Label("Paired · \(fp)", systemImage: "checkmark.seal")
                        }
                        Button("Unpair", role: .destructive) { model.unpair() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

struct TaskRow: View {
    let task: TrackedTask

    private var cs: GlanceActivityAttributes.ContentState { .init(from: task) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: glyph)
                    .foregroundStyle(tint)
                Text(task.name).font(.headline).lineLimit(1)
                Spacer()
                Text(task.kind.rawValue).font(.caption2).foregroundStyle(.secondary)
            }
            if let fraction = cs.fraction, !cs.isTerminal {
                ProgressView(value: fraction).tint(tint)
            }
            let subtitle = GlanceFormat.subtitle(cs)
            if !subtitle.isEmpty {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var glyph: String {
        switch task.state {
        case .running:  return "arrow.down.circle"
        case .stalled:  return "exclamationmark.triangle"
        case .done:     return "checkmark.circle.fill"
        case .failed:   return "xmark.octagon.fill"
        case .paused:   return "pause.circle"
        case .queued:   return "clock"
        }
    }

    private var tint: Color {
        switch task.state {
        case .done:    return .green
        case .failed:  return .red
        case .stalled: return .orange
        case .paused:  return .gray
        default:       return .blue
        }
    }
}
