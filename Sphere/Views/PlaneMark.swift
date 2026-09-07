import SwiftUI

/// Now, drawn as a plane, high above everything else in the sky.
///
/// It is not a decoration that happens to be tappable: it sits AT the real hour,
/// so its position is the answer to "where is now from here". Scrub away and it
/// drifts toward the edge and out; scrub back and it comes in to meet you. Tap
/// it and you fly to it, which lands you on now because that is where it lives.
///
/// Nothing here moves on its own. Like every other mark in this app it moves
/// because the wheel moved, so an idle screen is perfectly still.
struct PlaneMark: View {
    /// Hours from the focus to the real now. Positive means now is ahead of you.
    let hoursToNow: Double

    /// Far slower than the high deck's 0.85, because it is far further away
    /// than the clouds are — parallax is the whole depth cue, and it is also
    /// what decides how long the plane is visible. At 0.7 it left the screen at
    /// two hours out and then spent the rest of the fade invisible; at this rate
    /// it reaches the edge at about four and a half, which is exactly where it
    /// finishes fading. It goes and disappears in the same moment.
    static let parallax: CGFloat = 0.35

    /// Where it fades in and out, in hours from now. It is absent while you are
    /// home — its presence IS the message — comes up over the half hour after
    /// the window's edge passes, holds, and is gone by the time it has left the
    /// screen, which at this parallax happens at about four and a half hours.
    static let fadeIn: ClosedRange<Double> = 1.0...1.5
    static let fadeOut: ClosedRange<Double> = 3.0...4.5

    /// The one number worth tuning on the device.
    static let size: CGFloat = 26

    static func opacity(hoursToNow: Double) -> Double {
        let d = abs(hoursToNow)
        if d < fadeIn.lowerBound || d > fadeOut.upperBound { return 0 }
        if d < fadeIn.upperBound {
            return smooth((d - fadeIn.lowerBound) / (fadeIn.upperBound - fadeIn.lowerBound))
        }
        if d > fadeOut.lowerBound {
            return 1 - smooth((d - fadeOut.lowerBound) / (fadeOut.upperBound - fadeOut.lowerBound))
        }
        return 1
    }

    private static func smooth(_ t: Double) -> Double {
        let t = t.clamped(to: 0...1)
        return t * t * (3 - 2 * t)
    }

    /// Nose toward now, contrail behind. Heading is not computed from a bearing:
    /// it falls out of which side of you now is on.
    private var goingRight: Bool { hoursToNow > 0 }

    var body: some View {
        Canvas { context, size in
            let mid = CGPoint(x: size.width / 2, y: size.height / 2)
            let scale = size.height / 24
            let nose = goingRight ? 1.0 : -1.0

            var body = Path()
            // Fuselage: nose ahead, tail behind.
            body.move(to: CGPoint(x: mid.x + nose * 9 * scale, y: mid.y))
            body.addLine(to: CGPoint(x: mid.x - nose * 8 * scale, y: mid.y))

            // Wings, swept back from a point just behind the nose. Seen from
            // below, which is the only view this app can honestly have.
            let root = CGPoint(x: mid.x + nose * 1.5 * scale, y: mid.y)
            body.move(to: CGPoint(x: root.x - nose * 5.5 * scale, y: mid.y - 7 * scale))
            body.addLine(to: root)
            body.addLine(to: CGPoint(x: root.x - nose * 5.5 * scale, y: mid.y + 7 * scale))

            // Tailplane, a smaller echo at the back.
            let tail = CGPoint(x: mid.x - nose * 6.5 * scale, y: mid.y)
            body.move(to: CGPoint(x: tail.x - nose * 2.2 * scale, y: mid.y - 3.4 * scale))
            body.addLine(to: tail)
            body.addLine(to: CGPoint(x: tail.x - nose * 2.2 * scale, y: mid.y + 3.4 * scale))

            context.stroke(body, with: .color(Theme.ink),
                           style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))

            // The contrail says direction and speed without anything moving. It
            // fades to nothing so it never reads as a rule on the chart.
            var trail = Path()
            let from = CGPoint(x: mid.x - nose * 9 * scale, y: mid.y)
            let to = CGPoint(x: mid.x - nose * 26 * scale, y: mid.y)
            trail.move(to: from)
            trail.addLine(to: to)
            context.stroke(
                trail,
                with: .linearGradient(
                    Gradient(colors: [Theme.ink.opacity(0.5), Theme.ink.opacity(0)]),
                    startPoint: from, endPoint: to
                ),
                style: StrokeStyle(lineWidth: 1.1, lineCap: .round)
            )
        }
        // Wider than it is tall: the contrail lives inside the same canvas so it
        // fades with the plane rather than needing its own opacity.
        .frame(width: Self.size * 2.6, height: Self.size)
        .allowsHitTesting(false)
    }
}
