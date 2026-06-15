import SwiftUI

/// A thick, rounded progress bar.
/// - `running` true  → a vibrant orange→blue→bright-blue fill with a double glow
///   and a white "lightning" glint that sweeps along it, signalling live energy.
///   Determinate fills to `fraction`; nil fraction shows a gliding sweep.
/// - `running` false → solid `color` (the finished green/red state).
struct ThickBar: View {
    var fraction: Double?
    var color: Color = .glanceBlue
    var running: Bool = false
    var height: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var streak = false
    @State private var sweep = false

    private var liveGradient: LinearGradient {
        LinearGradient(colors: [.glanceOrange, .glanceBlue, .glanceBlueHi],
                       startPoint: .leading, endPoint: .trailing)
    }

    private func clamp(_ f: Double) -> Double { min(1, max(0, f)) }

    var body: some View {
        GeometryReader { geo in
            let w = max(height, geo.size.width * clamp(fraction ?? 0))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))

                if fraction != nil {
                    if running {
                        Capsule()
                            .fill(liveGradient)
                            .frame(width: w)
                            .overlay(lightning(width: w))
                            .clipShape(Capsule())
                            .shadow(color: Color.glanceBlue.opacity(0.75), radius: 7)
                            .shadow(color: Color.glanceBlueHi.opacity(0.45), radius: 14)
                    } else {
                        Capsule().fill(color).frame(width: w)
                    }
                } else {
                    // indeterminate: an orange→blue gradient gliding left↔right
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.glanceOrange.opacity(0.2), .glanceBlue, .glanceBlueHi.opacity(0.2)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * 0.4)
                        .offset(x: sweep && !reduceMotion ? geo.size.width * 0.6 : 0)
                        .animation(reduceMotion ? .default
                                   : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                                   value: sweep)
                        .shadow(color: Color.glanceBlue.opacity(0.6), radius: 8)
                }
            }
        }
        .frame(height: height)
        .onAppear { streak = true; sweep = true }
    }

    /// A bright glint that travels the length of the filled bar — the "lightning".
    private func lightning(width w: CGFloat) -> some View {
        let band = max(28, w * 0.32)
        return Capsule()
            .fill(LinearGradient(
                colors: [.clear, Color.white.opacity(0.95), Color.glanceBlueHi.opacity(0.6), .clear],
                startPoint: .leading, endPoint: .trailing))
            .frame(width: band)
            .blur(radius: 1.5)
            .offset(x: reduceMotion ? (w - band) / 2 : (streak ? w : -band))
            .animation(reduceMotion ? .default
                       : .linear(duration: 1.0).repeatForever(autoreverses: false),
                       value: streak)
    }
}
