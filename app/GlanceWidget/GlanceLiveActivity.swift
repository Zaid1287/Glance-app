import ActivityKit
import WidgetKit
import SwiftUI

/// A circular progress "wheel": determinate ring when the total is known,
/// indeterminate spinner when it isn't, and a check/✗ ring when finished.
/// Used across the Lock Screen, Dynamic Island, and the Apple Watch Smart Stack
/// (which mirrors the Lock Screen view for free).
struct StatusRing: View {
    let state: GlanceActivityAttributes.ContentState
    var size: CGFloat = 46
    var line: CGFloat = 5
    var showLabel = true

    var body: some View {
        ZStack {
            Circle().stroke(.tertiary, lineWidth: line)
            if state.isTerminal {
                Circle().stroke(stateTint(state), lineWidth: line)
                Image(systemName: state.state == "failed" ? "xmark" : "checkmark")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(stateTint(state))
            } else if let fraction = state.fraction {
                Circle()
                    .trim(from: 0, to: max(0.001, fraction))
                    .stroke(stateTint(state), style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if showLabel {
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(.system(size: size * 0.28, weight: .semibold))
                        .monospacedDigit()
                }
            } else {
                ProgressView().controlSize(size < 28 ? .mini : .small)
            }
        }
        .frame(width: size, height: size)
    }
}

struct GlanceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GlanceActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .padding(14)
                .activityBackgroundTint(Color.black.opacity(0.45))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StatusRing(state: s, size: 40, line: 4, showLabel: false)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if s.isTerminal {
                        Text(s.state == "failed" ? "Failed" : "Done")
                            .font(.caption).bold().foregroundStyle(stateTint(s))
                    } else if let eta = s.etaSeconds {
                        Text("ETA \(GlanceFormat.duration(eta))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(s.name).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(bottomLine(s))
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                StatusRing(state: s, size: 22, line: 3, showLabel: false)
            } compactTrailing: {
                Text(compactValue(s)).font(.caption2).monospacedDigit()
            } minimal: {
                StatusRing(state: s, size: 20, line: 3, showLabel: false)
            }
        }
    }
}

struct LockScreenView: View {
    let state: GlanceActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            StatusRing(state: state, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(state.name).font(.headline).lineLimit(1)
                Text(statusLine).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var statusLine: String {
        if state.isTerminal { return state.state == "failed" ? "Failed" : "Done" }
        let sub = GlanceFormat.subtitle(state)
        return sub.isEmpty ? (state.detail ?? "Working…") : sub
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

private func compactValue(_ s: GlanceActivityAttributes.ContentState) -> String {
    if s.isTerminal { return "" }
    if let f = s.fraction { return "\(Int((f * 100).rounded()))%" }
    if let c = s.completedUnitCount { return GlanceFormat.bytes(c) }
    return ""
}

private func bottomLine(_ s: GlanceActivityAttributes.ContentState) -> String {
    if s.isTerminal { return s.state == "failed" ? "Failed" : "Done" }
    let sub = GlanceFormat.subtitle(s)
    return sub.isEmpty ? (s.detail ?? "") : sub
}
