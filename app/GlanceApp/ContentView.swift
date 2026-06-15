import SwiftUI
import GlanceCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    private var active: [TrackedTask] { model.activeTasks }
    private var recent: [TrackedTask] { Array(model.recentTasks.prefix(20)) }

    var body: some View {
        ZStack {
            Color.glanceBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if active.isEmpty && recent.isEmpty {
                        emptyState
                    } else {
                        if !active.isEmpty {
                            sectionLabel("Active")
                            ForEach(active) { TaskCard(task: $0) }
                        }
                        if !recent.isEmpty {
                            sectionLabel("Recent")
                            ForEach(recent) { TaskCard(task: $0) }
                        }
                    }
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .tint(.glanceBlue)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Glance")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.glanceInk)
                statusLine
            }
            Spacer()
            menu
        }
    }

    private var statusLine: some View {
        Group {
            if active.isEmpty {
                Text("All quiet").foregroundStyle(Color.glanceMuted)
            } else {
                HStack(spacing: 6) {
                    Circle().fill(Color.glanceBlue).frame(width: 7, height: 7)
                    Text("\(active.count) running")
                        .foregroundStyle(Color.glanceBlueHi)
                }
            }
        }
        .font(.subheadline.weight(.medium))
    }

    private var menu: some View {
        Menu {
            if let fp = model.keyFingerprint {
                Label("Paired · \(fp)", systemImage: "checkmark.seal")
            }
            Button("Unpair", role: .destructive) { model.unpair() }
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline)
                .foregroundStyle(Color.glanceMuted)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.glanceSurface))
                .overlay(Circle().strokeBorder(Color.glanceBorder, lineWidth: 1))
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(Color.glanceFaint)
            .padding(.top, 2)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.glanceSurface).frame(width: 92, height: 92)
                Circle().strokeBorder(Color.glanceBorder, lineWidth: 1).frame(width: 92, height: 92)
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.glanceBlue)
            }
            Text("Nothing running")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.glanceInk)
            Text("Tasks on your Mac — downloads, builds, long jobs — show up here the moment they start.")
                .font(.callout)
                .foregroundStyle(Color.glanceMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Task card

struct TaskCard: View {
    let task: TrackedTask

    private var cs: GlanceActivityAttributes.ContentState { .init(from: task) }
    private var isActive: Bool { !cs.isTerminal }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                icon
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.headline)
                        .foregroundStyle(Color.glanceInk)
                        .lineLimit(1)
                    Text(task.kind.rawValue)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.glanceFaint)
                }
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isActive ? Color.glanceBlueHi : tint)
            }

            if isActive {
                ThickBar(fraction: cs.fraction, color: .glanceBlue, height: 10)
            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.glanceMuted)
            }
        }
        .glanceCard()
    }

    private var icon: some View {
        ZStack {
            Circle().fill(tint.opacity(0.16)).frame(width: 38, height: 38)
            Image(systemName: glyph).font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    private var value: String {
        if cs.isTerminal { return task.state == .failed ? "Failed" : "Done" }
        if let f = cs.fraction { return "\(Int((f * 100).rounded()))%" }
        if let c = cs.completedUnitCount { return GlanceFormat.bytes(c) }
        return ""
    }

    private var subtitle: String {
        if cs.isTerminal { return GlanceFormat.subtitle(cs) }
        let sub = GlanceFormat.subtitle(cs)
        return sub.isEmpty ? (cs.detail ?? "") : sub
    }

    private var glyph: String {
        switch task.state {
        case .running:  return "arrow.down.circle.fill"
        case .stalled:  return "exclamationmark.triangle.fill"
        case .done:     return "checkmark.circle.fill"
        case .failed:   return "xmark.octagon.fill"
        case .paused:   return "pause.circle.fill"
        case .queued:   return "clock.fill"
        }
    }

    private var tint: Color {
        switch task.state {
        case .done:    return .glanceGreen
        case .failed:  return .glanceRed
        case .stalled: return .glanceOrange
        case .paused:  return .glanceFaint
        default:       return .glanceBlue
        }
    }
}
