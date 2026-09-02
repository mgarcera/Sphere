import SwiftUI

/// Hand-drawn marks in the arc's own line: 1.3 stroke, round caps, geometric,
/// no fill except where a dot is the point.
///
/// Days are arcs here, the way they are everywhere else in the app, so stepping
/// a day is a run of arcs with an arrow on the end rather than a page turning.
/// The exception is the calendar itself, which is a grid of dots: the one place
/// borrowing the universal shape reads faster than restating the app's.
struct ActionMark: View {
    let action: WheelAction
    var size: CGFloat = 20
    var color: Color = Theme.ink

    private static let stroke = StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)

    var body: some View {
        Canvas { context, _ in
            let (strokes, fills) = Self.paths(for: action)
            context.stroke(strokes, with: .color(color), style: Self.stroke)
            context.fill(fills, with: .color(color))
        }
        .frame(width: size, height: size)
    }

    /// Everything is drawn in a 20-point box and scaled by the frame.
    private static func paths(for action: WheelAction) -> (Path, Path) {
        var line = Path()
        var solid = Path()

        /// A run of days: one quad curve per lobe, all sitting on one baseline.
        func scallop(from x0: CGFloat, to x1: CGFloat, lobes: Int, base: CGFloat, peak: CGFloat) {
            let width = (x1 - x0) / CGFloat(lobes)
            line.move(to: CGPoint(x: x0, y: base))
            for lobe in 0..<lobes {
                let start = x0 + width * CGFloat(lobe)
                line.addQuadCurve(to: CGPoint(x: start + width, y: base),
                                  control: CGPoint(x: start + width / 2, y: peak))
            }
        }

        /// Barbs only. The line they terminate is drawn by the caller, so the
        /// arrow reads as the end of the run rather than as a separate mark.
        func arrowhead(at x: CGFloat, y: CGFloat, pointingLeft: Bool) {
            let reach: CGFloat = pointingLeft ? 3.2 : -3.2
            line.move(to: CGPoint(x: x + reach, y: y - 2.8))
            line.addLine(to: CGPoint(x: x, y: y))
            line.addLine(to: CGPoint(x: x + reach, y: y + 2.8))
        }

        switch action {
        case .none:
            line.move(to: CGPoint(x: 5, y: 10))
            line.addLine(to: CGPoint(x: 15, y: 10))

        case .now:
            // The arc with the time dot on it: the app's own signature.
            scallop(from: 3, to: 17, lobes: 1, base: 14, peak: 3)
            solid.addEllipse(in: CGRect(x: 8, y: 6.5, width: 4, height: 4))

        case .calendar:
            // A month of dots, four across and three down.
            for row in 0..<3 {
                for column in 0..<4 {
                    let x = 4 + CGFloat(column) * 4
                    let y = 6 + CGFloat(row) * 4.5
                    solid.addEllipse(in: CGRect(x: x - 1.1, y: y - 1.1, width: 2.2, height: 2.2))
                }
            }

        case .previousDay:
            scallop(from: 5, to: 17, lobes: 3, base: 12.5, peak: 6.5)
            arrowhead(at: 5, y: 12.5, pointingLeft: true)

        case .nextDay:
            scallop(from: 3, to: 15, lobes: 3, base: 12.5, peak: 6.5)
            arrowhead(at: 15, y: 12.5, pointingLeft: false)

        case .newAllDay:
            // A whole day's baseline, and a plus above it.
            line.move(to: CGPoint(x: 2, y: 15))
            line.addLine(to: CGPoint(x: 18, y: 15))
            line.move(to: CGPoint(x: 10, y: 4))
            line.addLine(to: CGPoint(x: 10, y: 11))
            line.move(to: CGPoint(x: 6.5, y: 7.5))
            line.addLine(to: CGPoint(x: 13.5, y: 7.5))

        case .appearance:
            // One disc, half lit. The moon shape the header already uses.
            line.addEllipse(in: CGRect(x: 4, y: 4, width: 12, height: 12))
            solid.move(to: CGPoint(x: 10, y: 4))
            solid.addArc(center: CGPoint(x: 10, y: 10), radius: 6,
                         startAngle: .degrees(-90), endAngle: .degrees(90),
                         clockwise: false)
            solid.closeSubpath()

        case .search:
            line.addEllipse(in: CGRect(x: 3, y: 3, width: 11, height: 11))
            line.move(to: CGPoint(x: 12.8, y: 12.8))
            line.addLine(to: CGPoint(x: 17, y: 17))

        case .openCalendarApp:
            // A day, and an arrow leaving it.
            scallop(from: 2, to: 11, lobes: 1, base: 15, peak: 8)
            line.move(to: CGPoint(x: 11.5, y: 11.5))
            line.addLine(to: CGPoint(x: 17, y: 6))
            line.move(to: CGPoint(x: 12.5, y: 6))
            line.addLine(to: CGPoint(x: 17, y: 6))
            line.addLine(to: CGPoint(x: 17, y: 10.5))

        case .muteHaptics:
            solid.addEllipse(in: CGRect(x: 4, y: 8, width: 4, height: 4))
            for radius in [5.0, 8.0] {
                line.addArc(center: CGPoint(x: 6, y: 10), radius: radius,
                            startAngle: .degrees(-52), endAngle: .degrees(52),
                            clockwise: false)
            }
            line.move(to: CGPoint(x: 3, y: 17))
            line.addLine(to: CGPoint(x: 17, y: 3))
        }

        return (line, solid)
    }
}
