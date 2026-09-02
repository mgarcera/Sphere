import SwiftUI

/// A clock whose hands carry the hour the wheel is on, so it turns as you
/// scrub. Same idea as the time dot: one moment, read on every part of the
/// screen at once.
///
/// Two hands in a plain circle and nothing else. At caption size a tick face
/// reads as a grey ring rather than as ticks.
struct ClockFace: Shape {
    /// Local hour of day, 0 to 24, fractional.
    var hour: Double

    /// Lets the hands sweep when the hour animates, rather than jumping to the
    /// new position the way an unanimated shape would.
    var animatableData: Double {
        get { hour }
        set { hour = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        // Inset by half the stroke so the rim sits inside its frame.
        let radius = min(rect.width, rect.height) / 2 - 0.6

        path.addEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                                   width: radius * 2, height: radius * 2))

        func hand(turns: Double, length: CGFloat) {
            // Zero turns points at twelve, so the sweep starts a quarter back.
            let angle = turns * 2 * .pi - .pi / 2
            path.move(to: centre)
            path.addLine(to: CGPoint(x: centre.x + length * cos(angle),
                                     y: centre.y + length * sin(angle)))
        }

        hand(turns: hour.truncatingRemainder(dividingBy: 12) / 12, length: radius * 0.48)
        hand(turns: (hour * 60).truncatingRemainder(dividingBy: 60) / 60, length: radius * 0.76)

        return path
    }
}
