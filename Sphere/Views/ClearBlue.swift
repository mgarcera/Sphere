import SwiftUI

/// The blue of a clear day, in the same band every other wash uses.
///
/// The colour is measured, not picked: `65A2E4`, read off a photograph of real
/// sky. It sits at the band's first stop, with the zenith deepened above it and
/// the horizon paled below, which is the direction sky actually runs.
///
/// Read off the file, not off the upload: the same photograph arrived as a 97
/// x 173 JPEG and sampled `A9BDE1`, a washed-out periwinkle nowhere near the
/// real thing. A colour that has been through a resize and a lossy encode is
/// not the colour.
///
/// It answers to three things at once so it never fights what is already drawn:
///
/// - **Cloud, weighted by deck.** Low cloud closes the sky; cirrus barely
///   touches it. Overcast at 30,000 feet is still a blue day from underneath.
/// - **The sun's height**, not the clock. It is gone by the time the twilight
///   wash takes over, because two washes competing for the same band is what
///   makes a screen look muddy.
/// - **Weather**, which suppresses it the way it suppresses the night. A storm
///   does not get a blue sky behind it.
struct ClearBlue: View {
    @Environment(\.colorScheme) private var colorScheme
    /// 0 overcast, 1 cloudless.
    let clearness: Double
    let elevationDegrees: Double
    var suppressedBy: Double = 0
    /// STUDY (2026-10-09): variant A. The wash runs to the bottom edge instead of dying at
    /// `Fall.out`, so the screen is one field and that stop stops meaning anything.
    var reachesBottom = false

    /// Where the blue reaches full strength. Below this the sun is low enough
    /// that the sky is turning warm and the twilight wash owns the band.
    static let fullSunDegrees: Double = 15
    static let peakOpacity: Double = 0.92

    /// The measured colour, kept as components so the header can composite it.
    static let topComponents  = (r: 0.290, g: 0.549, b: 0.847)  // 4A8CD8, zenith

    private var gradientStops: [Gradient.Stop] {
        let band: [Gradient.Stop] = [
            .init(color: colors[0], location: 0),
            .init(color: colors[1], location: TwilightBackground.Fall.first),
            .init(color: colors[2], location: TwilightBackground.Fall.second),
        ]
        guard reachesBottom else {
            return band + [.init(color: Theme.background.opacity(0), location: TwilightBackground.Fall.out)]
        }
        // Carry the horizon colour the rest of the way rather than fading out. Stepped rather
        // than a single long ramp: one stop across 400-odd points of near-identical blue bands
        // on an OLED, and that would read as a property of the option.
        let tail = (1...6).map { step -> Gradient.Stop in
            let t = Double(step) / 6
            let location = TwilightBackground.Fall.second
                + (1 - TwilightBackground.Fall.second) * t
            return .init(color: colors[2].mix(with: horizonFloor, by: t), location: location)
        }
        return band + tail
    }

    /// Where the full-field version lands at the bottom edge: the horizon blue, carried down and
    /// slightly deepened so the screen has a direction rather than a flat wash.
    private var horizonFloor: Color {
        colorScheme == .dark
            ? Color(red: 0.090, green: 0.145, blue: 0.231)
            : Color(red: 0.737, green: 0.847, blue: 0.957)
    }

    static func strength(clearness: Double, elevationDegrees: Double, suppressedBy: Double) -> Double {
        let height = min(max(elevationDegrees / fullSunDegrees, 0), 1)
        return clearness * height * (1 - min(suppressedBy, 1))
    }

    private var colors: [Color] {
        colorScheme == .dark
            // A night that happens to be cloudless is not a blue sky, so the
            // dark end is barely more than a cool cast on the ground.
            ? [Color(red: 0.098, green: 0.180, blue: 0.302),
               Color(red: 0.129, green: 0.227, blue: 0.373),
               Color(red: 0.161, green: 0.267, blue: 0.427)]
            : [Color(red: 0.290, green: 0.549, blue: 0.847),   // 4A8CD8  zenith
               Color(red: 0.396, green: 0.635, blue: 0.894),   // 65A2E4  the photograph
               Color(red: 0.639, green: 0.780, blue: 0.937)]   // A3C7EF  toward the horizon
    }

    var body: some View {
        LinearGradient(stops: gradientStops, startPoint: .top, endPoint: .bottom)
        .opacity(Self.strength(clearness: clearness,
                               elevationDegrees: elevationDegrees,
                               suppressedBy: suppressedBy) * Self.peakOpacity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
