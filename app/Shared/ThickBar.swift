import SwiftUI

/// A thick, rounded progress bar matching the website's Live Activity mock.
/// `fraction` nil = indeterminate (a soft pulsing sweep — used for downloads with
/// no known total). Determinate fills with a subtle gradient of `color`.
struct ThickBar: View {
    var fraction: Double?
    var color: Color = .glanceBlue
    var height: CGFloat = 12

    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                if let fraction {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [color, color.opacity(0.78)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(height, geo.size.width * min(1, max(0, fraction))))
                } else {
                    // indeterminate: a gradient sweep gliding left↔right
                    Capsule()
                        .fill(LinearGradient(
                            colors: [color.opacity(0.15), color, color.opacity(0.15)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * 0.4)
                        .offset(x: pulse ? geo.size.width * 0.6 : 0)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                        .onAppear { pulse = true }
                }
            }
        }
        .frame(height: height)
    }
}
