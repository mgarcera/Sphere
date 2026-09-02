import SwiftUI

/// The ground warms as the focus hour passes through the horizon, and is plain
/// white the rest of the time.
///
/// It follows the focus hour rather than the real one, so it agrees with the
/// dot: turning the wheel through dawn warms the screen. Kept well under full
/// strength, since the app is ink on white and the line work has to stay
/// readable through it.
struct TwilightBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    let elevationDegrees: Double
    /// True on the rising half of the day, which is what separates dawn's
    /// palette from dusk's.
    let isMorning: Bool
    /// 0 to 1. Weather takes precedence, so dusk does not tint a storm.
    var suppressedBy: Double = 0

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
                .init(color: colors[1], location: 0.20),
                .init(color: colors[2], location: 0.40),
                .init(color: Theme.background.opacity(0), location: 0.52),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
            .opacity(strength * Self.peakOpacity * (1 - min(suppressedBy, 1)))
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}
