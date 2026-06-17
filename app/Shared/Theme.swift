import SwiftUI

/// Canonical project links, defined once so the app never hardcodes the URL twice.
enum GlanceLinks {
    static let website = URL(string: "https://zaid1287.github.io/Glance")!
}

/// Brand palette, ported from the website's dark-grey + blue-accent system
/// (docs/style.css OKLCH tokens) into sRGB. Shared by the app and the widget
/// so the Live Activity, the task list, and the marketing site all agree.
extension Color {
    static let glanceBg        = Color(.sRGB, red: 0.071, green: 0.078, blue: 0.094) // base
    static let glanceBg2       = Color(.sRGB, red: 0.051, green: 0.058, blue: 0.071) // deeper
    static let glanceSurface   = Color(.sRGB, red: 0.118, green: 0.129, blue: 0.149) // raised card
    static let glanceSurfaceHi = Color(.sRGB, red: 0.160, green: 0.172, blue: 0.196) // hover/elevated
    static let glanceInk       = Color(.sRGB, red: 0.960, green: 0.965, blue: 0.975) // primary text
    static let glanceMuted     = Color(.sRGB, red: 0.640, green: 0.660, blue: 0.700) // secondary text
    static let glanceFaint     = Color(.sRGB, red: 0.480, green: 0.500, blue: 0.550) // tertiary text
    static let glanceBlue      = Color(.sRGB, red: 0.230, green: 0.510, blue: 0.970) // accent
    static let glanceBlueHi    = Color(.sRGB, red: 0.520, green: 0.720, blue: 1.000) // accent light
    static let glanceGreen     = Color(.sRGB, red: 0.300, green: 0.830, blue: 0.520) // done
    static let glanceOrange    = Color(.sRGB, red: 0.960, green: 0.650, blue: 0.140) // stalled
    static let glanceRed       = Color(.sRGB, red: 1.000, green: 0.420, blue: 0.420) // failed
    static let glanceBorder    = Color.white.opacity(0.08)
}

/// The liquid-glass card surface used across the app: raised solid fill, hairline
/// border, soft shadow — the native echo of the site's `.tile` / `.la` surfaces.
struct GlanceCardBackground: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.glanceSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.glanceBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)
    }
}

extension View {
    func glanceCard(padding: CGFloat = 16) -> some View {
        modifier(GlanceCardBackground(padding: padding))
    }
}
