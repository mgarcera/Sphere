import SwiftUI

/// The ground darkens under rain and darkens further under a storm, the same
/// way it warms at dawn and dusk.
///
/// Like the twilight wash it follows the FOCUS hour, so it agrees with the dot
/// and turning the wheel into a storm darkens the screen. It sits over the
/// twilight wash, since weather is nearer than the time of day.
struct WeatherWash: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Millimetres in the hour, interpolated.
    let precipitation: Double
    /// 0 to 1, interpolated, so a storm fades in rather than snapping on.
    let lightning: Double

    private static let rainPeak: Double = 0.5
    private static let stormPeak: Double = 0.72

    private var rainStrength: Double {
        min(precipitation / 2.5, 1) * (1 - lightning * 0.6)
    }

    var body: some View {
        ZStack {
            gradient(rainColors)
                .opacity(rainStrength * Self.rainPeak)
            gradient(stormColors)
                .opacity(min(lightning, 1) * Self.stormPeak)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func gradient(_ colors: [Color]) -> some View {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    /// Slate, going nowhere near blue enough to compete with the event colours.
    private var rainColors: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.11, green: 0.15, blue: 0.21),
               Color(red: 0.15, green: 0.19, blue: 0.24),
               Theme.background]
            : [Color(red: 0.44, green: 0.51, blue: 0.59),
               Color(red: 0.66, green: 0.71, blue: 0.76),
               Theme.background]
    }

    /// Dark blue-grey overhead with the flash low, where the cloud base is.
    private var stormColors: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.09, green: 0.12, blue: 0.19),
               Color(red: 0.20, green: 0.22, blue: 0.28),
               Color(red: 0.52, green: 0.44, blue: 0.18),
               Theme.background]
            : [Color(red: 0.29, green: 0.34, blue: 0.44),
               Color(red: 0.50, green: 0.54, blue: 0.61),
               Color(red: 0.92, green: 0.84, blue: 0.46),
               Theme.background]
    }
}
