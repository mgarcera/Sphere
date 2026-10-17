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

    /// The four accents the choice marks carry (Mason, 2026-10-16). One part of each mark is not
    /// ink: the ink draws the DAY, which every mark shares, and the accent draws the ACT, which
    /// is the one thing each mark says that the others do not. The plus, the lens rim, the date
    /// being picked, the present moment.
    ///
    /// Colour is not new to this canvas. `EventLayer` has stroked every event in its own
    /// calendar's colour since the arc was drawn, so the drawing already carries hue and the
    /// marks were the monochrome exception.
    ///
    /// Pigment rather than candy, and each one is a light/dark pair because the ground goes from
    /// white to near-black. Amber stands in for yellow: a true yellow has almost no contrast
    /// against paper, and these have to read on both grounds.
    static let markGreen = Color("MarkGreen")
    static let markBlue  = Color("MarkBlue")
    static let markRed   = Color("MarkRed")
    static let markAmber = Color("MarkAmber")
}

/// How dark the SKY is at a given sun elevation, 0 by day and 1 once the sun is
/// properly down. Nautical twilight (-12°) is where the last light goes.
///
/// It is not the app's appearance: the ground never moves. Only the band above
/// the horizon reads this.
enum SkyDepth {
    static let nightDegrees: Double = -12

    static func nightness(elevationDegrees: Double) -> Double {
        // No `clamped` here: this file is compiled into the widget too, and
        // that helper lives with the app's model. The stdlib's own `clamped` is
        // package-internal and silently returns a Duration.
        let t = min(max(-elevationDegrees / -nightDegrees, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

extension Theme {
    /// The ink for marks ABOVE the horizon — clouds, stars, birds, rain. It
    /// lightens as the sky darkens, so a cloud keeps its weight against
    /// whatever it is sitting on.
    ///
    /// In dark mode `ink` is already near-white, so the blend is a no-op there
    /// and one expression covers both appearances.
    static func skyInk(nightness: Double) -> Color {
        ink.mix(with: Color(red: 0.949, green: 0.933, blue: 0.910), by: nightness)
    }
}

extension Font {
    /// Display/title face. `.serif` resolves to New York on iOS.
    static func display(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
}

/// Light, dark, or follow the device. Every colour is an asset-catalog pair,
/// so overriding the scheme is all this has to do.
/// Natural Sky or Dark. Two settings, and that is the whole list.
///
/// **There is no "follow the system", and no plain Light.** Natural Sky
/// replaced both: "decide for me" means the sun decides rather than the phone's
/// switch, and a fixed Light is a day that never ends, which is the opposite of
/// what this app draws. Dark stays because a dark app at noon is a real thing
/// people want and the sun cannot give it to them.
///
/// The cost is taken knowingly: someone who wants Sphere light at midnight, or
/// who schedules their phone's appearance and wants Sphere to agree, no longer
/// has a way to ask. Any stored value other than `"dark"` falls back to the
/// default, which is `sky` — the intended migration from both `"system"` and
/// `"light"`.
enum Appearance: String, CaseIterable, Identifiable {
    /// Light by day, dark at night, cutting between them at the horizon.
    case sky
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sky: "Natural Sky"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        // The sun's own answer depends on the hour, so the view works it out;
        // this is only the day half.
        case .sky: .light
        case .dark: .dark
        }
    }
}

// ORPHANED DOC, kept as the record of a deleted idea rather than left looking live.
//
// Everything below documented `ContrastHold`, which held a role's text at a fixed contrast ratio
// against whatever the header was sitting on, capping as well as raising: on a clear day the ink
// measured about 15:1 and was brought down to the title's target. The type went on 2026-10-09
// when the app became two colours, and `ContentView` records the reason — "a two-colour system
// has no ratio to hold and no escape hatch to need". The prose stayed behind, in present tense,
// in the file the widget target also compiles, until 2026-10-13.
//
/// Light mode only. In dark mode the ink is already light and the ground only