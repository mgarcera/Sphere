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

    /// How far either side of the horizon the wash reaches.
    private static let spanDegrees: Double = 8
    private static let peakOpacity: Double = 0.85

    private var strength: Double {
        max(0, 1 - abs(elevationDegrees) / Self.spanDegrees)
    }

    /// Dawn runs cool into cream, dusk runs plum into amber. They were two
    /// shades of the same peach before, which read as one effect happening
    /// twice.
    private var colors: [Color] {
        colorScheme == .dark ? darkColors : lightColors
    }

    private var lightColors: [Color] {
        isMorning
            ? [Color(red: 0.62, green: 0.70, blue: 0.88),
               Color(red: 0.90, green: 0.76, blue: 0.82),
               Color(red: 0.99, green: 0.90, blue: 0.74),
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
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .opacity(strength * Self.peakOpacity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}
