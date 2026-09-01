import SwiftUI

/// The ground darkens under rain and darkens further under a storm.
///
/// Like the twilight wash it follows the FOCUS hour, so it agrees with the dot
/// and turning the wheel into a storm darkens the screen. Unlike twilight it is
/// weighted to the TOP of the screen and clears before the drawing starts:
/// darkening the band would cost the arc and the clouds their contrast, and
/// they cannot be recoloured per frame without giving up the cached layers.
/// Overhead is where weather belongs anyway.
struct WeatherWash: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Millimetres in the hour, interpolated.
    let precipitation: Double
    /// 0 to 1, interpolated, so a storm fades in rather than snapping on.
    let lightning: Double

    static let rainPeak: Double = 0.5
    static let stormPeak: Double = 0.78

    static func rainStrength(precipitation: Double, lightning: Double) -> Double {
        min(precipitation / 2.5, 1) * (1 - min(lightning, 1) * 0.6)
    }

    /// How much the top of the screen has been darkened, 0 to 1. The header
    /// reads this to keep its text legible, and the twilight wash reads it to
    /// get out of the way.
    static func darkness(precipitation: Double, lightning: Double) -> Double {
        min(rainStrength(precipitation: precipitation, lightning: lightning) * rainPeak
            + min(lightning, 1) * stormPeak, 1)
    }

    var body: some View {
        ZStack {
            gradient(rainColors)
                .opacity(Self.rainStrength(precipitation: precipitation, lightning: lightning) * Self.rainPeak)
            gradient(stormColors)
                .opacity(min(lightning, 1) * Self.stormPeak)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Full strength across the header, gone by the time the arc block begins.
    private func gradient(_ colors: [Color]) -> some View {
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
    }

    /// Slate, nowhere near blue enough to compete with the event colours.
    private var rainColors: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.11, green: 0.15, blue: 0.21),
               Color(red: 0.14, green: 0.18, blue: 0.23),
               Color(red: 0.16, green: 0.19, blue: 0.24)]
            : [Color(red: 0.42, green: 0.49, blue: 0.58),
               Color(red: 0.56, green: 0.62, blue: 0.69),
               Color(red: 0.74, green: 0.78, blue: 0.83)]
    }

    /// Deeper and colder than rain, and no yellow: the flash lives with the
    /// lightning, not in the sky's own colour.
    private var stormColors: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.07, green: 0.10, blue: 0.16),
               Color(red: 0.10, green: 0.13, blue: 0.20),
               Color(red: 0.13, green: 0.16, blue: 0.23)]
            : [Color(red: 0.22, green: 0.27, blue: 0.37),
               Color(red: 0.35, green: 0.40, blue: 0.49),
               Color(red: 0.58, green: 0.63, blue: 0.70)]
    }
}
