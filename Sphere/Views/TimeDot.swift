import SwiftUI

/// The cursor, carrying what the sky is doing at the hour it sits on.
///
/// Everything keys off the sun's elevation, the same number the arc's height
/// comes from. Below the horizon it is the moon at tonight's phase; at zero it
/// is a bare disc, which is sunrise; above, the rays lengthen with elevation
/// and are longest at solar noon. There is no threshold to tune and the dot can
/// never contradict the curve.
struct TimeDot: View {
    let elevationDegrees: Double
    let moon: MoonPhase
    /// Elevation at which the rays reach full length, roughly the year's peak
    /// at this latitude.
    let ceilingDegrees: Double

    private static let discDiameter: CGFloat = 15
    private static let rayCount = 8
    private static let rayInner: CGFloat = 9
    private static let rayOuter: CGFloat = 21

    var body: some View {
        ZStack {
            // A ring of background keeps the dot legible wherever a capsule
            // runs beneath it.
            Circle()
                .fill(Theme.background)
                .frame(width: 22, height: 22)

            SunRays(reach: rayReach)
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: Self.rayOuter * 2, height: Self.rayOuter * 2)

            // One shape for both, always present. There used to be an
            // if/else here between a sun and a moon, and inside a withAnimation
            // transaction SwiftUI gives a branch change its default OPACITY
            // transition — so crossing the horizon during a jump faded the dot
            // out and back rather than letting it travel.
            //
            // A full moon is a disc, so the sun is simply this shape fully lit.
            MoonShape(illuminated: litFraction, isWaxing: moon.isWaxing)
                .fill(Theme.ink)
                .overlay(Circle().strokeBorder(Theme.ink.opacity(0.32), lineWidth: 1))
                .frame(width: Self.discDiameter, height: Self.discDiameter)
        }
        .frame(width: Self.rayOuter * 2, height: Self.rayOuter * 2)
    }

    /// How far into daylight, over the first few degrees above the horizon.
    /// The disc fills to a solid sun across this, while the rays grow from
    /// nothing, so sunrise is a morph rather than a swap.
    private var litFraction: Double {
        let dayness = min(max(elevationDegrees / 6, 0), 1)
        return moon.illuminated + (1 - moon.illuminated) * dayness
    }

    /// 0 at the horizon, 1 at the seasonal ceiling.
    private var rayReach: Double {
        min(max(elevationDegrees, 0) / max(ceilingDegrees, 1), 1)
    }

    /// Rays keep a fixed count and change length. A changing count would pop,
    /// and would rebuild the shape on every frame of a scrub.
    private struct SunRays: Shape {
        var reach: Double

        var animatableData: Double {
            get { reach }
            set { reach = newValue }
        }

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let centre = CGPoint(x: rect.midX, y: rect.midY)
            let outer = TimeDot.rayInner + (TimeDot.rayOuter - TimeDot.rayInner) * reach
            guard outer > TimeDot.rayInner + 0.5 else { return path }

            for index in 0..<TimeDot.rayCount {
                let angle = Double(index) * 2 * .pi / Double(TimeDot.rayCount) - .pi / 2
                path.move(to: CGPoint(
                    x: centre.x + TimeDot.rayInner * cos(angle),
                    y: centre.y + TimeDot.rayInner * sin(angle)
                ))
                path.addLine(to: CGPoint(
                    x: centre.x + outer * cos(angle),
                    y: centre.y + outer * sin(angle)
                ))
            }
            return path
        }
    }
}

/// The lit part of the moon, bounded by the limb on one side and the
/// terminator on the other. The terminator is a half ellipse whose width runs
/// from the full radius at new, through zero at the quarters, to the radius
/// again at full, so one sampled outline covers every phase.
struct MoonShape: Shape {
    var illuminated: Double
    var isWaxing: Bool

    /// Without this the terminator jumps between values instead of sweeping,
    /// which is what turns sunrise into a morph.
    var animatableData: Double {
        get { illuminated }
        set { illuminated = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let terminator = radius * (1 - 2 * illuminated)
        let side: CGFloat = isWaxing ? 1 : -1
        let steps = 48

        for step in 0...steps {
            let t = Double.pi * Double(step) / Double(steps)
            let point = CGPoint(
                x: centre.x + side * radius * sin(t),
                y: centre.y - radius * cos(t)
            )
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        for step in stride(from: steps, through: 0, by: -1) {
            let t = Double.pi * Double(step) / Double(steps)
            path.addLine(to: CGPoint(
                x: centre.x + side * terminator * sin(t),
                y: centre.y - radius * cos(t)
            ))
        }
        path.closeSubpath()
        return path
    }
}
