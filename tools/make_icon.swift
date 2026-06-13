// Renders the Glance app icon at any pixel size in a Liquid-Glass style:
// a translucent progress ring with specular highlights, a glass center sphere,
// and a drop shadow over a layered blue gradient. All dimensions scale with the
// canvas so every icon variant (incl. the 20pt notification icon) is crisp.
// Usage: swift tools/make_icon.swift <output.png> [pixelSize=1024]
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let S = Double(CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "1024") ?? 1024
let px = Int(S.rounded())
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: px, height: px, bitsPerComponent: 8,
    bytesPerRow: px * 4, space: cs,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("ctx") }

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}
let center = CGPoint(x: S / 2, y: S / 2)

// ---- background: blue gradient + soft light blobs ----
let bg = CGGradient(colorsSpace: cs,
    colors: [rgb(0.36, 0.69, 1.0), rgb(0.03, 0.24, 0.86)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])

func blob(_ p: CGPoint, _ r: Double, _ color: CGColor) {
    let g = CGGradient(colorsSpace: cs, colors: [color, rgb(0, 0, 0, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: r, options: [])
}
blob(CGPoint(x: S * 0.26, y: S * 0.80), S * 0.55, rgb(0.65, 0.90, 1.0, 0.45))
blob(CGPoint(x: S * 0.82, y: S * 0.18), S * 0.50, rgb(0.10, 0.10, 0.55, 0.40))

let radius = S * 0.305
let lw = S * 0.090

// ---- track ring ----
ctx.saveGState()
ctx.setLineWidth(lw); ctx.setLineCap(.round)
ctx.setStrokeColor(rgb(1, 1, 1, 0.18))
ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.strokePath()
ctx.restoreGState()

let start = CGFloat.pi / 2
let sweep = CGFloat.pi * 2 * 0.72

// ---- progress arc: drop shadow ----
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.021), blur: S * 0.039, color: rgb(0, 0, 0, 0.35))
ctx.setLineWidth(lw); ctx.setLineCap(.round)
ctx.setStrokeColor(rgb(1, 1, 1, 0.9))
ctx.addArc(center: center, radius: radius, startAngle: start, endAngle: start - sweep, clockwise: true)
ctx.strokePath()
ctx.restoreGState()

// ---- progress arc: glassy gradient ----
ctx.saveGState()
ctx.setLineWidth(lw); ctx.setLineCap(.round)
ctx.addArc(center: center, radius: radius, startAngle: start, endAngle: start - sweep, clockwise: true)
ctx.replacePathWithStrokedPath()
ctx.clip()
let ringGrad = CGGradient(colorsSpace: cs,
    colors: [rgb(1, 1, 1, 0.98), rgb(0.80, 0.90, 1.0, 0.55)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(ringGrad,
    start: CGPoint(x: center.x, y: center.y + radius + lw),
    end: CGPoint(x: center.x, y: center.y - radius - lw), options: [])
ctx.restoreGState()

// ---- specular highlight ----
ctx.saveGState()
ctx.setLineWidth(lw * 0.34); ctx.setLineCap(.round)
ctx.setStrokeColor(rgb(1, 1, 1, 0.95))
ctx.addArc(center: center, radius: radius + lw * 0.22, startAngle: .pi * 0.95, endAngle: .pi * 0.62, clockwise: true)
ctx.strokePath()
ctx.restoreGState()

// ---- center glass sphere ----
let dotR = S * 0.057
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.010), blur: S * 0.018, color: rgb(0, 0, 0, 0.30))
let sphere = CGGradient(colorsSpace: cs,
    colors: [rgb(1, 1, 1, 1.0), rgb(0.78, 0.88, 1.0, 0.85)] as CFArray, locations: [0, 1])!
ctx.addEllipse(in: CGRect(x: center.x - dotR, y: center.y - dotR, width: dotR * 2, height: dotR * 2))
ctx.clip()
ctx.drawRadialGradient(sphere,
    startCenter: CGPoint(x: center.x - dotR * 0.35, y: center.y + dotR * 0.35), startRadius: 1,
    endCenter: center, endRadius: dotR * 1.4, options: [])
ctx.restoreGState()
ctx.setFillColor(rgb(1, 1, 1, 0.95))
ctx.fillEllipse(in: CGRect(x: center.x - dotR * 0.42, y: center.y + dotR * 0.18, width: dotR * 0.4, height: dotR * 0.4))

// ---- export ----
guard let img = ctx.makeImage() else { fatalError("img") }
let url = URL(fileURLWithPath: outPath) as CFURL
guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else { fatalError("dest") }
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("write") }
print("wrote \(outPath) (\(px)px)")
