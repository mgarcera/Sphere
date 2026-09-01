import SwiftUI

/// The ground warms as the focus hour passes through the horizon, and is plain
/// white the rest of the time.
///
/// It follows the focus hour rather than the real one, so it agrees with the
/// dot: turning the wheel through dawn warms the screen. Kept well under full
/// strength, since the app is ink on white and the line work has to stay
/// readable through it.
struct TwilightBackground: View {
    let elevationDegrees: Double
    /// True on the rising half of the day, which is what separates dawn's
    /// palette from dusk's.
    let isMorning: Bool

    /// How far either side of the horizon the wash reaches.
    private static let spanDegrees: Double = 8
    private static let peakOpacity: Double = 0.5

    private var strength: Double {
        max(0, 1 - abs(elevationDegrees) / Self.spanDegrees)
    }

    private var colors: [Color] {
        isMorning
            ? [Color(red: 0.99, green: 0.90, blue: 0.86),
               Color(red: 0.99, green: 0.95, blue: 0.87),
               Theme.background]
            : [Color(red: 0.99, green: 0.87, blue: 0.79),
               Color(red: 0.97, green: 0.85, blue: 0.83),
               Theme.background]
    }

    var body: some View {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .opacity(strength * Self.peakOpacity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}
