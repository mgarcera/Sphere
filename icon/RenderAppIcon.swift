// Sphere's app icon, drawn rather than stored — so it can be regenerated at any
// size and retuned without redrawing it by hand.
//
//   swift icon/RenderAppIcon.swift Sphere/Assets.xcassets/AppIcon.appiconset
//
// The icon is the app's own mechanism: the night is bounded by the sun's own
// path (NightSky), the field is the twilight wash (TwilightBackground), and the
// boundary brightens toward the sun and dies just past it — so the edge reads
// as the day already travelled. The sun sits off the crest at 0.66; centred, a
// symmetric curve reads as a landscape rather than as a moment in a day.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF)/255,
            green: CGFloat((hex >> 8) & 0xFF)/255,
            blue: CGFloat(hex & 0xFF)/255, alpha: a)
}

let night = 0x0B0E19 as UInt32          // NightSky.colour
let S: CGFloat = 1024
let NOW: CGFloat = 0.66                 // where the sun has got to

/// E1 · LIFTED — the trail strength that shipped.
let trailMin: CGFloat = 8, trailMax: CGFloat = 34
let trailPeak: CGFloat = 0.85, trailGamma: CGFloat = 1.8, trailTail: CGFloat = 0.10

/// The day's curve, the same shape ArcGeometry draws.
struct Arc {
    var rise: CGFloat = 0.02, set: CGFloat = 0.98
    var baseline: CGFloat = 0.80, peak: CGFloat = 0.16

    func y(_ t: CGFloat) -> CGFloat {
        guard t > rise, t < set else { return baseline * S }
        return (baseline - peak * sin(.pi * (t - rise) / (set - rise))) * S
    }
    func point(_ t: CGFloat) -> CGPoint { CGPoint(x: t * S, y: y(t)) }
    func path(steps: Int = 400) -> CGMutablePath {
        let p = CGMutablePath()
        for i in 0...steps {
            let pt = point(CGFloat(i) / CGFloat(steps))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        return p
    }
}

func gradient(_ stops: [(UInt32, CGFloat, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
               colors: stops.map { rgb($0.0, $0.2) } as CFArray,
               locations: stops.map { $0.1 })!
}
func vertical(_ c: CGContext, _ g: CGGradient, from y0: CGFloat = 0, to y1: CGFloat = S) {
    c.drawLinearGradient(g, start: CGPoint(x: 0, y: y0), end: CGPoint(x: 0, y: y1),
                         options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// How lit the path is at `t`: climbing to the sun, cut off just past it.
func heatAt(_ t: CGFloat) -> CGFloat {
    if t <= NOW { return pow(max(0, (t - 0.02) / (NOW - 0.02)), trailGamma) }
    return max(0, 1 - (t - NOW) / trailTail)
}

/// One gradient through a clip, sampled fine. Stepping a stroke's alpha bands
/// it; stepping a round-capped one beads it. Both were visible at 1024.
func lightRamp(_ c: CGContext, _ colour: UInt32, peak: CGFloat, floor: CGFloat) {
    var cols: [CGColor] = [], locs: [CGFloat] = []
    for i in 0...80 {
        let t = CGFloat(i) / 80
        cols.append(rgb(colour, floor + peak * heatAt(t))); locs.append(t)
    }
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: cols as CFArray, locations: locs)!
    c.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: S, y: 0),
                         options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// A ribbon that follows the curve and swells toward the sun, walked out along
/// the normal and back — a stroke can only have one width.
func ribbon(_ arc: Arc, steps: Int = 300) -> CGPath {
    var top: [CGPoint] = [], bottom: [CGPoint] = []
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps)
        let p = arc.point(t)
        let ahead = arc.point(min(t + 0.002, 1)), behind = arc.point(max(t - 0.002, 0))
        let d = CGPoint(x: ahead.x - behind.x, y: ahead.y - behind.y)
        let len = max(sqrt(d.x * d.x + d.y * d.y), 0.0001)
        let n = CGPoint(x: -d.y / len, y: d.x / len)
        let half = (trailMin + (trailMax - trailMin) * heatAt(t)) / 2
        top.append(CGPoint(x: p.x + n.x * half, y: p.y + n.y * half))
        bottom.append(CGPoint(x: p.x - n.x * half, y: p.y - n.y * half))
    }
    let path = CGMutablePath()
    path.addLines(between: top + bottom.reversed())
    path.closeSubpath()
    return path
}

func icon(dark: Bool) -> CGImage {
    // No alpha: App Store icons must be opaque.
    let c = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    c.translateBy(x: 0, y: S); c.scaleBy(x: 1, y: -1)   // y grows downward
    let arc = Arc()

    // Below the curve: the lit part of the sky.
    // The bottom band is hazed rather than saturated. At full gold it read as
    // ground — a lit dune under the ridge — which is the one thing this icon
    // must not be, since the whole image is sky.
    vertical(c, gradient(dark
        ? [(0x2B2138, 0, 1), (0x5E3A44, 0.42, 1), (0x87593F, 0.78, 1), (0xA37B55, 1, 1)]
        : [(0x6A4A63, 0, 1), (0x9E5A57, 0.40, 1), (0xDE9463, 0.80, 1), (0xEBCB94, 1, 1)]),
        from: 0.52 * S, to: S)

    // Above it: the night, filled once, bounded by the sun's own path.
    let sky = arc.path()
    sky.addLine(to: CGPoint(x: S, y: -10)); sky.addLine(to: CGPoint(x: 0, y: -10)); sky.closeSubpath()
    c.saveGState(); c.addPath(sky); c.clip()
    vertical(c, gradient(dark
        ? [(0x03040A, 0, 1), (night, 0.55, 1), (0x11172E, 1, 1)]
        : [(night, 0, 1), (0x1B2242, 0.55, 1), (0x2E2E52, 1, 1)]), to: arc.baseline * S)
    c.restoreGState()

    // The crossing, carrying the day already travelled.
    c.saveGState(); c.addPath(ribbon(arc)); c.clip()
    lightRamp(c, 0xFFE8C0, peak: trailPeak * (dark ? 0.86 : 1), floor: dark ? 0.05 : 0.08)
    c.restoreGState()

    // The sun.
    let sun = arc.point(NOW), r: CGFloat = 104
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [rgb(0xFFE6A8, dark ? 0.34 : 0.50), rgb(0xFFE6A8, 0)] as CFArray,
                          locations: [0, 1])!
    c.drawRadialGradient(glow, startCenter: sun, startRadius: r * 0.6,
                         endCenter: sun, endRadius: r * 3, options: [])
    c.setFillColor(rgb(dark ? 0xE9D5A0 : 0xFFEDBE))
    c.fillEllipse(in: CGRect(x: sun.x - r, y: sun.y - r, width: r * 2, height: r * 2))

    // The horizon, held low.
    c.setStrokeColor(rgb(0xFFE9C8, dark ? 0.16 : 0.26)); c.setLineWidth(7)
    c.move(to: CGPoint(x: 0, y: 0.945 * S)); c.addLine(to: CGPoint(x: S, y: 0.945 * S))
    c.strokePath()

    return c.makeImage()!
}

let dir = URL(fileURLWithPath: CommandLine.arguments[1])
for (name, dark) in [("AppIcon-light.png", false), ("AppIcon-dark.png", true)] {
    let d = CGImageDestinationCreateWithURL(dir.appendingPathComponent(name) as CFURL,
                                            UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, icon(dark: dark), nil)
    CGImageDestinationFinalize(d)
    print("wrote \(name)")
}
