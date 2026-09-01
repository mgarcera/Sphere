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

    /// How much wash is present, 0 to 1. Twilight reads this to get out of the
    /// way. It is NOT a measure of how dark the result is: full rain scores 0.5
    /// yet composites to a light grey, while a storm scores 0.78 and composites
    /// to near-black. Anything deciding a text colour must use the luminance
    /// below instead.
    static func amount(precipitation: Double, lightning: Double) -> Double {
        min(rainStrength(precipitation: precipitation, lightning: lightning) * rainPeak
            + min(lightning, 1) * stormPeak, 1)
    }

    /// Top-of-screen colours as components, so the header can composite them
    /// and measure what it is actually sitting on.
    static let lightRainTop = (r: 0.42, g: 0.49, b: 0.58)
    static let lightStormTop = (r: 0.22, g: 0.27, b: 0.37)

    /// Relative luminance at the top of the screen in light mode, where the
    /// header sits.
    static func topLuminance(precipitation: Double, lightning: Double,
                             twilight: (color: (r: Double, g: Double, b: Double), opacity: Double)) -> Double {
        var c = (r: 1.0, g: 1.0, b: 1.0)
        func over(_ top: (r: Double, g: Double, b: Double), _ alpha: Double) {
            c = (c.r * (1 - alpha) + top.r * alpha,
                 c.g * (1 - alpha) + top.g * alpha,
                 c.b * (1 - alpha) + top.b * alpha)
        }
        // Twilight goes on first, since it sits under the weather.
        over(twilight.color, twilight.opacity)
        over(lightRainTop, rainStrength(precipitation: precipitation, lightning: lightning) * rainPeak)
        over(lightStormTop, min(lightning, 1) * stormPeak)

        func linear(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
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
            : [Color(red: Self.lightRainTop.r, green: Self.lightRainTop.g, blue: Self.lightRainTop.b),
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
            : [Color(red: Self.lightStormTop.r, green: Self.lightStormTop.g, blue: Self.lightStormTop.b),
               Color(red: 0.35, green: 0.40, blue: 0.49),
               Color(red: 0.58, green: 0.63, blue: 0.70)]
    }
}
