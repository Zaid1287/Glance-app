import SwiftUI

/// A thick, rounded progress bar.
/// - `running` true  → energetic orange→blue gradient that gently pulses, to
///   signal "this is live". Determinate fills to `fraction`; nil fraction shows a
///   gliding indeterminate sweep.
/// - `running` false → solid `color` (used for the finished green/red state).
struct ThickBar: View {
    var fraction: Double?
    var color: Color = .glanceBlue
    var running: Bool = false
    var height: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var sweep = false

    private var liveGradient: LinearGradient {
        LinearGradient(colors: [.glanceOrange, .glanceBlue],
                       startPoint: .leading, endPoint: .trailing)
    }

    private func clamp(_ f: Double) -> Double { min(1, max(0, f)) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))

                if let fraction {
                    Capsule()
                        .fill(running ? AnyShapeStyle(liveGradient) : AnyShapeStyle(color))
                        .frame(width: max(height, geo.size.width * clamp(fraction)))
                        .shadow(color: running ? Color.glanceBlue.opacity(0.45) : .clear,
                                radius: running ? 6 : 0)
                        .opacity(running && pulse && !reduceMotion ? 0.7 : 1)
                        .animation(running && !reduceMotion
                                   ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                                   : .default,
                                   value: pulse)
                } else {
                    // indeterminate: an orange→blue gradient gliding left↔right
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.glanceOrange.opacity(0.2), .glanceBlue, Color.glanceBlue.opacity(0.2)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * 0.4)
                        .offset(x: sweep && !reduceMotion ? geo.size.width * 0.6 : 0)
                        .animation(reduceMotion ? .default
                                   : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                                   value: sweep)
                }
            }
        }
        .frame(height: height)
        .onAppear { pulse = true; sweep = true }
    }
}
