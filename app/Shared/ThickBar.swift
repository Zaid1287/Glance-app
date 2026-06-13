import SwiftUI

/// A thick, rounded progress bar. `fraction` nil = indeterminate (track only —
/// used for downloads with no known total). Determinate fills with `color`.
struct ThickBar: View {
    var fraction: Double?
    var color: Color = .blue
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.35))
                if let fraction {
                    Capsule()
                        .fill(color)
                        .frame(width: max(height, geo.size.width * min(1, max(0, fraction))))
                }
            }
        }
        .frame(height: height)
    }
}
