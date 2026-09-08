import SwiftUI

/// The sky: one layer, from the top of the screen down to the horizon.
///
/// It does two jobs that used to be one. It warms as the focus hour passes
/// through the horizon — dawn cool into cream, dusk plum into amber — and it
/// DARKENS once the sun is properly down, so the band above the arc is a night
/// sky while the ground below it stays paper. Drawn once rather than as two
/// layers meeting somewhere, because a seam across the screen is the one thing
/// that would give it away.
///
/// It follows the focus hour rather than the real one, so it agrees with the
/// dot: turning the wheel through dusk darkens the sky.
struct TwilightBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    let elevationDegrees: Double
    /// True on the rising half of the day, which is what separates dawn's
    /// palette from dusk's.
    let isMorning: Bool
    /// 0 to 1. Weather takes precedence, so dusk does not tint a storm.
    var suppressedBy: Double = 0

    /// Where every wash on this screen sits, vertically. Full strength across
    /// the header, gone before the arc block — the night, the twilight tint and
    /// the weather all read from here, so moving them is one edit rather than
    /// three.
    ///
    /// Taking them to half the screen was tried and pulled back: the fade then
    /// ran past the horizon and into the hour labels.
    enum Fall {
        /// The mood stops of a three-colour wash.
        static let first: Double = 0.20
        static let second: Double = 0.40
        /// Where a two-colour wash stops being solid.
        static let hold: Double = 0.34
        /// Where all of them reach zero.
        static let out: Double = 0.52
    }

    /// How far either side of the horizon the wash reaches.
    static let spanDegrees: Double = 8
    static let peakOpacity: Double = 0.85

    static func strength(elevationDegrees: Double) -> Double {
        max(0, 1 - abs(elevationDegrees) / spanDegrees)
    }

    /// Top-of-screen colour as components, so the header can composite it and
    /// measure what it is sitting on. Light mode only; in dark mode the ink is
    /// already light and the ground only gets darker.
    static func lightTopColor(isMorning: Bool) -> (r: Double, g: Double, b: Double) {
        isMorning ? (0.62, 0.70, 0.88) : (0.70, 0.55, 0.66)
    }

    /// The night fill at the top of the screen, and how much of it there is —
    /// the header measures what it is ACTUALLY on, and since this arrived it is
    /// no longer paper. Without it the title stays dark on a dark sky.
    static let nightTopComponents = (r: 0.043, g: 0.055, b: 0.098)

    static func nightOpacity(elevationDegrees: Double, suppressedBy: Double) -> Double {
        SkyDepth.nightness(elevationDegrees: elevationDegrees) * (1 - min(suppressedBy, 1))
    }

    private var strength: Double {
        Self.strength(elevationDegrees: elevationDegrees)
    }

    /// Dawn runs cool into cream, dusk runs plum into amber. They were two
    /// shades of the same peach before, which read as one effect happening
    /// twice.
    private var colors: [Color] {
        colorScheme == .dark ? darkColors : lightColors
    }

    private var lightColors: [Color] {
        isMorning
            // Matched stop by stop to dusk's composited luminance rather than
            // its opacity, which was already identical: dusk simply used
            // darker colours, so it read stronger at the same 0.85.
            ? [Color(red: 0.526, green: 0.594, blue: 0.747),
               Color(red: 0.753, green: 0.636, blue: 0.686),
               Color(red: 0.926, green: 0.842, blue: 0.692),
               Theme.background]
            : [Color(red: 0.70, green: 0.55, blue: 0.66),
               Color(red: 0.95, green: 0.58, blue: 0.38),
               Color(red: 0.99, green: 0.83, blue: 0.55),
               Theme.background]
    }

    /// Dark keeps the same two moods, pitched so the ground stays a ground.
    private var darkColors: [Color] {
        isMorning
            ? [Color(red: 0.16, green: 0.20, blue: 0.36),
               Color(red: 0.34, green: 0.22, blue: 0.32),
               Color(red: 0.42, green: 0.30, blue: 0.20),
               Theme.background]
            : [Color(red: 0.22, green: 0.13, blue: 0.24),
               Color(red: 0.44, green: 0.20, blue: 0.14),
               Color(red: 0.38, green: 0.26, blue: 0.16),
               Theme.background]
    }

    var body: some View {
        // Same stops as the weather wash: full strength across the header,
        // gone before the arc block, so every wash reads as sky rather than as
        // a tint over the whole screen.
        LinearGradient(
            stops: [
                .init(color: colors[0], location: 0),
                .init(color: colors[1], location: Fall.first),
                .init(color: colors[2], location: Fall.second),
                .init(color: Theme.background.opacity(0), location: Fall.out),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .opacity(strength * Self.peakOpacity * (1 - min(suppressedBy, 1)))
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
