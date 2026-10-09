import SwiftUI

/// The sky as ONE FLAT COLOUR across the whole screen, changing with the
/// hour rather than with height. Decided with Mason after variant A of the fill study won and
/// he asked for the colours to be uniform.
///
/// What this replaces when it is on: `ClearBlue`'s vertical ramp, `TwilightBackground`'s wash,
/// and `NightSky`'s shaped fill — three views whose job was to put colour in different places on
/// the screen. A flat field has no places. `WeatherWash` stays, because rain and lightning are
/// content rather than ground.
///
/// `TwilightBackground.Fall` retires with them: its own comment calls it "where every wash on
/// this screen sits, vertically", and a flat field has no vertical. The bake-off that chose this
/// over a gradient and over the shipped band is recorded in DECISIONS, 2026-10-09.
/// One colour for the whole screen, from where the sun is.
///
/// Four anchors, because that is how many distinct things the sky does: night, the deep edge
/// either side of the horizon, the warm low sun, and full day. Everything between them is a
/// straight interpolation, so there are no stops to tune and no band to place.
struct SkyField: View {
    @Environment(\.colorScheme) private var colorScheme
    let elevationDegrees: Double
    /// 0 overcast, 1 cloudless. An overcast noon is a flatter, greyer blue, not a dimmer one.
    let clearness: Double
    var suppressedBy: Double = 0

    var body: some View {
        let pair = Self.pair(elevationDegrees: elevationDegrees,
                             clearness: clearness,
                             suppressedBy: suppressedBy,
                             dark: colorScheme == .dark)
        LinearGradient(stops: Self.stops(pair), startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    /// Nine stops rather than two. One ramp across 900 points of near-identical hue bands
    /// visibly on an OLED, and a verdict on a banded render is a verdict on the banding.
    static func stops(_ pair: (top: RGB, bottom: RGB)) -> [Gradient.Stop] {
        (0...8).map { step in
            let t = Double(step) / 8
            return .init(color: pair.top.mix(pair.bottom, by: t).color, location: t)
        }
    }

    /// The single colour, kept for anything that needs one value for the whole field — the
    /// polarity decision reads this rather than sampling the gradient.
    static func colour(elevationDegrees: Double, clearness: Double, suppressedBy: Double, dark: Bool) -> Color {
        let p = pair(elevationDegrees: elevationDegrees, clearness: clearness,
                     suppressedBy: suppressedBy, dark: dark)
        return p.top.mix(p.bottom, by: 0.5).color
    }

    /// Each anchor is a PAIR now — what the sky is overhead, and what it is at the horizon
    /// (Mason, 2026-10-09, reversing the flat decision once rain showed what depth buys).
    /// A flat field could not say the one thing a real dusk does, which is warm low and cool
    /// high; two colours per anchor can, and it costs nothing at noon where the pair is just
    /// the zenith and the horizon blue the app already owned.
    static func pair(elevationDegrees e: Double,
                     clearness: Double,
                     suppressedBy: Double,
                     dark: Bool) -> (top: RGB, bottom: RGB) {
        let night: (RGB, RGB) = dark
            ? (RGB(0.031, 0.035, 0.059), RGB(0.063, 0.071, 0.110))
            : (RGB(0.075, 0.094, 0.157), RGB(0.153, 0.180, 0.263))
        // Civil twilight: the earth's shadow above, the last light at the horizon.
        let edge: (RGB, RGB) = dark
            ? (RGB(0.071, 0.082, 0.141), RGB(0.176, 0.141, 0.169))
            : (RGB(0.224, 0.243, 0.373), RGB(0.482, 0.365, 0.396))
        // The low sun, and the reason this reversal happened: cool overhead, warm at the bottom.
        let low: (RGB, RGB) = dark
            ? (RGB(0.122, 0.149, 0.231), RGB(0.306, 0.208, 0.188))
            : (RGB(0.455, 0.569, 0.733), RGB(0.949, 0.733, 0.584))
        // Noon is the pair ClearBlue always used: zenith to horizon.
        let day: (RGB, RGB) = dark
            ? (RGB(0.098, 0.180, 0.302), RGB(0.161, 0.267, 0.427))
            : (RGB(ClearBlue.topComponents.r, ClearBlue.topComponents.g, ClearBlue.topComponents.b),
               RGB(0.639, 0.780, 0.937))

        let base: (RGB, RGB)
        switch e {
        case ..<(-6):   base = night
        case ..<0:      base = (edge.0.mix(night.0, by: -e / 6), edge.1.mix(night.1, by: -e / 6))
        case ..<15:     base = (low.0.mix(day.0, by: e / 15), low.1.mix(day.1, by: e / 15))
        default:        base = day
        }
        // Overcast pulls each end toward its OWN grey, so a dull day keeps the sky's direction
        // and loses only its colour. Weather suppression does the same thing harder.
        let amount = (1 - clearness) * 0.65 + min(suppressedBy, 1) * 0.35
        return (base.0.mix(RGB(base.0.luminance, base.0.luminance, base.0.luminance), by: amount),
                base.1.mix(RGB(base.1.luminance, base.1.luminance, base.1.luminance), by: amount))
    }

    /// Every mark on the field is pure black or pure white, and nothing in between
    /// (Mason, 2026-10-09). Hierarchy comes from size and weight instead of from grey.
    ///
    /// The flip is at relative luminance 0.179, which is where black and white give the same
    /// ratio against a background — so the WORST case anywhere in the day is 4.58:1, still above
    /// the 4.5:1 body-text bar. Measured across the field's own anchors: 6.0:1 for black on the
    /// noon blue, 9.4:1 at low sun, 19.3:1 for white at night. There is no dead zone, which is
    /// the whole reason a two-colour system is affordable here.
    ///
    /// It SNAPS. No cross-fade, because a cross-fade's midpoint is a grey and there are no greys.
    static func mark(on field: Color) -> Color {
        RGB(field).relativeLuminance >= Self.flipPoint ? .black : .white
    }

    /// Where black and white are equally legible: sqrt(0.05 × 1.05) − 0.05.
    static let flipPoint: Double = 0.1791
}

/// A tiny colour struct so the mixing above reads as arithmetic rather than as SwiftUI.
struct RGB {
    var r: Double, g: Double, b: Double
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    init(_ color: Color) {
        let ui = UIColor(color)
        var rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0, aa: CGFloat = 0
        ui.getRed(&rr, green: &gg, blue: &bb, alpha: &aa)
        self.init(Double(rr), Double(gg), Double(bb))
    }
    var color: Color { Color(red: r, green: g, blue: b) }
    /// Rec. 709 on the ENCODED values. Fine for mixing toward grey, wrong for contrast: use
    /// `relativeLuminance` for anything deciding legibility.
    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    /// WCAG relative luminance, which linearises first. The distinction matters: the gamma
    /// version puts the noon blue at 0.52 and this puts it at 0.25, and the flip point sits
    /// between the two — so using the wrong one would invert the ink in broad daylight.
    var relativeLuminance: Double {
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
    func mix(_ other: RGB, by t: Double) -> RGB {
        let k = min(max(t, 0), 1)
        return RGB(r + (other.r - r) * k, g + (other.g - g) * k, b + (other.b - b) * k)
    }
}
