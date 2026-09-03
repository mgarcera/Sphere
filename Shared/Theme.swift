import SwiftUI

/// Named colors live in Assets.xcassets so they stay editable outside code.
/// Hex values come from the palette table in the product brief.
enum Theme {
    static let background   = Color("Background")
    static let ink          = Color("Ink")
    static let muted        = Color("Muted")
    static let mutedLight   = Color("MutedLight")
    static let mutedLighter = Color("MutedLighter")
    static let hairline     = Color("Hairline")
    static let hairlineSoft = Color("HairlineSoft")
    static let taskActive   = Color("TaskActive")
    static let taskInactive = Color("TaskInactive")

    /// Tint for switches and pickers. NOT `ink`: in dark mode ink is nearly
    /// white, and a near-white track under a white knob makes a toggle read as
    /// one solid white pill with no visible state.
    static let controlAccent = Color("ControlAccent")
}

extension Font {
    /// Display/title face. `.serif` resolves to New York on iOS.
    static func display(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
}

/// Light, dark, follow the device, or follow the sun. Every colour is an
/// asset-catalog pair, so overriding the scheme is all this has to do.
///
/// `sun` reads the sun's elevation at the hour the wheel is on, so the screen
/// is light while the sun is up THERE and dark once it has set, and scrubbing
/// across a sunset carries the whole surface over with it. Raw values are
/// unchanged, so a preference stored before `sun` existed still decodes.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark, sun

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        case .sun: "Sun"
        }
    }

    /// The band around the horizon inside which `sun` holds whatever it last
    /// decided. Elevation is read from the wheel, and the wheel can be parked
    /// on a crossing and jogged; without a band the screen would strobe there.
    /// Half a degree is about the sun's own width, and two minutes of a day.
    static let sunHysteresis: Double = 0.5

    /// Nil means "no opinion, use the device's". The elevation is only read by
    /// `sun`; the other three ignore it.
    func colorScheme(elevationDegrees: Double, holding held: ColorScheme) -> ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        case .sun:
            if elevationDegrees > Self.sunHysteresis { .light }
            else if elevationDegrees < -Self.sunHysteresis { .dark }
            else { held }
        }
    }
}

/// Holds a role's text at a fixed contrast ratio against whatever the header is
/// actually sitting on, so the title and the caption keep the same relationship
/// in every condition.
///
/// This caps as well as raises: on a clear day the ink measures about 15:1 and
/// is deliberately brought down to the title's target, because a gap that only
/// holds in some conditions is what made the caption catch the title at dusk.
/// The cost is a lighter title on the most common screen of all.
///
/// Light mode only. In dark mode the ink is already light and the ground only
/// ever gets darker, so the designed colours hold.
enum ContrastHold {
    typealias RGB = (r: Double, g: Double, b: Double)

    static let ink: RGB = (0.169, 0.149, 0.125)
    static let muted: RGB = (0.541, 0.541, 0.541)
    static let paper: RGB = (1, 1, 1)

    static func luminance(_ c: RGB) -> Double {
        func linear(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }

    static func contrast(_ a: Double, _ b: Double) -> Double {
        (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private static func blend(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        (a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
    }

    /// The colour that puts `designed` at `target` against a ground of
    /// `backgroundLuminance`, keeping the designed hue by mixing rather than
    /// picking a neutral grey. When the ground cannot support the target in any
    /// direction the mix runs to the end and takes the best available.
    static func color(_ designed: RGB, target: Double, on backgroundLuminance: Double) -> Color {
        let bg = backgroundLuminance
        let current = contrast(luminance(designed), bg)

        let toward: RGB
        if current > target {
            // Too strong: fade toward the ground until it lands on target.
            toward = bg > 0.5 ? paper : (r: 0.07, g: 0.066, b: 0.063)
        } else {
            // Too weak: head for whichever extreme the ground leaves room for.
            toward = contrast(0, bg) >= contrast(1, bg) ? (r: 0, g: 0, b: 0) : paper
        }

        var low = 0.0
        var high = 1.0
        for _ in 0..<14 {
            let mid = (low + high) / 2
            let reached = contrast(luminance(blend(designed, toward, mid)), bg)
            let overshot = current > target ? reached <= target : reached >= target
            if overshot { high = mid } else { low = mid }
        }

        let result = blend(designed, toward, high)
        return Color(red: result.r, green: result.g, blue: result.b)
    }
}
