import ActivityKit
import WidgetKit
import SwiftUI

/// Straight (linear) progress bar: fills blue when a total/% is known, an
/// indeterminate linear bar when it isn't, and a full bar + ✓/✗ when finished.
/// Renders on the Lock Screen, Dynamic Island, and the Apple Watch Smart Stack.
struct GlanceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GlanceActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.45))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: stateGlyph(s)).foregroundStyle(stateTint(s))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(trailing(s)).font(.caption).bold()
                        .foregroundStyle(s.isTerminal ? stateTint(s) : Color.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(s.name).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        progressBar(s)
                        if !subtitle(s).isEmpty {
                            Text(subtitle(s)).font(.caption2).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: stateGlyph(s)).foregroundStyle(stateTint(s))
            } compactTrailing: {
                Text(compactValue(s)).font(.caption2).monospacedDigit().foregroundStyle(stateTint(s))
            } minimal: {
                Image(systemName: stateGlyph(s)).foregroundStyle(stateTint(s))
            }
        }
    }
}

struct LockScreenView: View {
    let state: GlanceActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: stateGlyph(state)).foregroundStyle(stateTint(state))
                Text(state.name).font(.headline).lineLimit(1)
                Spacer()
                Text(trailing(state)).font(.subheadline).bold()
                    .foregroundStyle(state.isTerminal ? stateTint(state) : Color.secondary)
            }
            progressBar(state)
            if !subtitle(state).isEmpty {
                Text(subtitle(state)).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

@ViewBuilder
private func progressBar(_ s: GlanceActivityAttributes.ContentState) -> some View {
    if s.isTerminal {
        ThickBar(fraction: 1, color: stateTint(s))
    } else if let fraction = s.fraction {
        ThickBar(fraction: fraction, running: true)
    } else {
        ThickBar(fraction: nil, running: true)
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
    case "done":    return .glanceGreen
    case "failed":  return .glanceRed
    case "stalled": return .glanceOrange
    case "paused":  return .glanceFaint
    default:        return .glanceBlue
    }
}

private func trailing(_ s: GlanceActivityAttributes.ContentState) -> String {
    if s.isTerminal { return s.state == "failed" ? "Failed" : "Done" }
    if let f = s.fraction { return "\(Int((f * 100).rounded()))%" }
    if let c = s.completedUnitCount { return GlanceFormat.bytes(c) }
    return ""
}

private func compactValue(_ s: GlanceActivityAttributes.ContentState) -> String {
    if s.isTerminal { return s.state == "failed" ? "✗" : "✓" }
    if let f = s.fraction { return "\(Int((f * 100).rounded()))%" }
    if let c = s.completedUnitCount { return GlanceFormat.bytes(c) }
    return ""
}

private func subtitle(_ s: GlanceActivityAttributes.ContentState) -> String {
    if s.isTerminal { return s.state == "failed" ? "Failed" : "Done" }
    let sub = GlanceFormat.subtitle(s)
    return sub.isEmpty ? (s.detail ?? "") : sub
}
