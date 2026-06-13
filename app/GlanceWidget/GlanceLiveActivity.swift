import ActivityKit
import WidgetKit
import SwiftUI

/// The headline surface: a Live Activity per active task on the Lock Screen +
/// Dynamic Island. Driven locally from LAN updates (no push needed near the Mac).
struct GlanceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GlanceActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .padding(14)
                .activityBackgroundTint(Color.black.opacity(0.45))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: stateGlyph(context.state)).foregroundStyle(stateTint(context.state))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let eta = context.state.etaSeconds {
                        Text("ETA \(GlanceFormat.duration(eta))").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.name).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        if let fraction = context.state.fraction {
                            ProgressView(value: fraction).tint(stateTint(context.state))
                        }
                        Text(GlanceFormat.subtitle(context.state))
                            .font(.caption2).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } compactLeading: {
                Image(systemName: stateGlyph(context.state)).foregroundStyle(stateTint(context.state))
            } compactTrailing: {
                Text(compactValue(context.state)).font(.caption2)
            } minimal: {
                Image(systemName: stateGlyph(context.state)).foregroundStyle(stateTint(context.state))
            }
        }
    }

    private func compactValue(_ s: GlanceActivityAttributes.ContentState) -> String {
        if let f = s.fraction { return String(format: "%.0f%%", f * 100) }
        if let c = s.completedUnitCount { return GlanceFormat.bytes(c) }
        return ""
    }
}

struct LockScreenView: View {
    let state: GlanceActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: stateGlyph(state))
                .font(.title2)
                .foregroundStyle(stateTint(state))
            VStack(alignment: .leading, spacing: 5) {
                Text(state.name).font(.headline).lineLimit(1)
                if let fraction = state.fraction, !state.isTerminal {
                    ProgressView(value: fraction).tint(stateTint(state))
                }
                Text(GlanceFormat.subtitle(state).isEmpty ? (state.detail ?? "") : GlanceFormat.subtitle(state))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

private func stateGlyph(_ s: GlanceActivityAttributes.ContentState) -> String {
    switch s.state {
    case "done":    return "checkmark.circle.fill"
    case "failed":  return "xmark.octagon.fill"
    case "stalled": return "exclamationmark.triangle.fill"
    case "paused":  return "pause.circle.fill"
    default:        return "arrow.down.circle.fill"
    }
}

private func stateTint(_ s: GlanceActivityAttributes.ContentState) -> Color {
    switch s.state {
    case "done":    return .green
    case "failed":  return .red
    case "stalled": return .orange
    case "paused":  return .gray
    default:        return .blue
    }
}
