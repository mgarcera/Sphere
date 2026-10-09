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
        Self.colour(elevationDegrees: elevationDegrees,
                    clearness: clearness,
                    suppressedBy: suppressedBy,
                    dark: colorScheme == .dark)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    static func colour(elevationDegrees e: Double,
                       clearness: Double,
                       suppressedBy: Double,
                       dark: Bool) -> Color {
        let night  = dark ? RGB(0.047, 0.055, 0.086) : RGB(0.118, 0.141, 0.212)
        let edge   = dark ? RGB(0.098, 0.110, 0.169) : RGB(0.306, 0.306, 0.400)
        let low    = dark ? RGB(0.196, 0.169, 0.188) : RGB(0.788, 0.655, 0.580)
        let day    = dark ? RGB(0.161, 0.267, 0.427) : RGB(ClearBlue.topComponents.r,
                                                           ClearBlue.topComponents.g,
                                                           ClearBlue.topComponents.b)
        let base: RGB
        switch e {
        case ..<(-6):   base = night
        case ..<0:      base = edge.mix(night, by: -e / 6)
        case ..<15:     base = low.mix(day, by: e / 15)
        default:        base = day
        }
        // Overcast pulls toward the field's own grey rather than toward white, so a dull day is
        // still the same sky. Weather suppression does the same thing harder.
        let grey = RGB(base.luminance, base.luminance, base.luminance)
        let flattened = base.mix(grey, by: (1 - clearness) * 0.65 + min(suppressedBy, 1) * 0.35)
        return flattened.color
    }

    /// Ink that stays legible on whatever the field is doing, computed rather than chosen.
    /// A light field gets dark ink and a dark field gets light ink, and the distance from the
    /// field is constant, so dusk does not get a weaker contrast than noon.
    static func ink(on field: Color, dark: Bool, muted: Bool = false) -> Color {
        let l = RGB(field).luminance
        let target = l > 0.5 ? max(0, l - (muted ? 0.46 : 0.62)) : min(1, l + (muted ? 0.52 : 0.70))
        return RGB(target, target, target).color
    }
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
    /// Rec. 709, the same weighting the eye uses, so "light" means light rather than numerically big.
    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }
    func mix(_ other: RGB, by t: Double) -> RGB {
        let k = min(max(t, 0), 1)
        return RGB(r + (other.r - r) * k, g + (other.g - g) * k, b + (other.b - b) * k)
    }
}
