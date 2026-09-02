import SwiftUI

/// Hand-drawn marks in the arc's own line: 1.3 stroke, round caps, geometric,
/// no fill except where a dot is the point.
///
/// Days are arcs here, the way they are everywhere else in the app: a whole arc
/// is a day, half of one is a point in it. The exceptions borrow universal
/// shapes where those read faster than restating the app's would — a grid of
/// dots for the calendar.
///
/// The four directional marks share one construction: arrows, then a straight
/// line, then that line rising into a day. One arrow steps an event and two
/// step a day, so the pair is told apart by a count rather than by two
/// unrelated drawings.
/// Everything the wheel can be drawn as, taps included.
///
/// Kept apart from `WheelAction` so that giving MENU a picture does not put it
/// in the pool of things a hold can be set to.
enum Mark {
    case none, now, calendar, previousDay, nextDay, newAllDay
    case appearance, search, openCalendarApp, muteHaptics
    case menu, openEvent, previousEvent, nextEvent
}

extension WheelAction {
    var mark: Mark {
        switch self {
        case .none: .none
        case .now: .now
        case .calendar: .calendar
        case .previousDay: .previousDay
        case .nextDay: .nextDay
        case .newAllDay: .newAllDay
        case .appearance: .appearance
        case .search: .search
        case .openCalendarApp: .openCalendarApp
        case .muteHaptics: .muteHaptics
        }
    }
}

extension WheelPosition {
    /// What tapping this position looks like. The bottom's follows its setting.
    var tapMark: Mark {
        switch self {
        case .previous: .previousEvent
        case .next: .nextEvent
        case .menu: .menu
        case .centre: .openEvent
        case .bottom: WheelMapping.bottomPrimary.mark
        }
    }
}

struct ActionMark: View {
    let mark: Mark
    var size: CGFloat = 20
    var color: Color = Theme.ink

    private static let stroke = StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)

    var body: some View {
        Canvas { context, _ in
            let (strokes, fills) = Self.paths(for: mark)
            context.stroke(strokes, with: .color(color), style: Self.stroke)
            context.fill(fills, with: .color(color))
        }
        .frame(width: size, height: size)
    }

    /// Everything is drawn in a 20-point box and scaled by the frame.
    private static func paths(for mark: Mark) -> (Path, Path) {
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
        func arrowhead(at x: CGFloat, y: CGFloat, pointingLeft: Bool, reach: CGFloat = 3.2) {
            let dx = pointingLeft ? reach : -reach
            line.move(to: CGPoint(x: x + dx, y: y - reach * 0.875))
            line.addLine(to: CGPoint(x: x, y: y))
            line.addLine(to: CGPoint(x: x + dx, y: y + reach * 0.875))
        }

        /// A line that becomes a day, with arrows on the leading end: one for
        /// an event, two for a day. Count carries the whole distinction, which
        /// survives the 16-point row where a difference in lobes did not.
        func run(arrows: Int, lobes: Int, goingLeft: Bool) {
            let base: CGFloat = 12
            let reach: CGFloat = arrows == 1 ? 3.2 : 2.6
            let spacing: CGFloat = 3.4
            let tip: CGFloat = goingLeft ? 2.6 : 17.4
            let straight: CGFloat = 5.5

            for arrow in 0..<arrows {
                let offset = CGFloat(arrow) * spacing * (goingLeft ? 1 : -1)
                arrowhead(at: tip + offset, y: base, pointingLeft: goingLeft, reach: reach)
            }

            // The line starts at the outermost arrow and runs back into the
            // scallop, so the two read as one stroke rather than two marks.
            let shaft = tip + CGFloat(arrows - 1) * spacing * (goingLeft ? 1 : -1)
            let joint = goingLeft ? shaft + straight : shaft - straight
            line.move(to: CGPoint(x: shaft, y: base))
            line.addLine(to: CGPoint(x: joint, y: base))

            let far: CGFloat = goingLeft ? 18 : 2
            scallop(from: min(joint, far), to: max(joint, far), lobes: lobes, base: base, peak: 5)
        }

        /// An event, drawn the way the arc draws one.
        func capsule(x: CGFloat, width: CGFloat) {
            line.addRoundedRect(in: CGRect(x: x, y: 8, width: width, height: 4),
                                cornerSize: CGSize(width: 2, height: 2))
        }

        switch mark {
        case .none:
            line.move(to: CGPoint(x: 5, y: 10))
            line.addLine(to: CGPoint(x: 15, y: 10))

        case .now:
            // Only the falling half, from the apex down, with the dot near the
            // end of it. A whole arc is a day; half of one is a point in it.
            line.move(to: CGPoint(x: 3, y: 5))
            line.addQuadCurve(to: CGPoint(x: 17, y: 15), control: CGPoint(x: 11, y: 5.5))
            solid.addEllipse(in: CGRect(x: 12.5, y: 9.6, width: 4, height: 4))

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
            run(arrows: 2, lobes: 1, goingLeft: true)

        case .nextDay:
            run(arrows: 2, lobes: 1, goingLeft: false)

        case .newAllDay:
            // A whole day, and a plus above its apex.
            scallop(from: 2, to: 18, lobes: 1, base: 17, peak: 7)
            line.move(to: CGPoint(x: 10, y: 1.5))
            line.addLine(to: CGPoint(x: 10, y: 8.5))
            line.move(to: CGPoint(x: 6.5, y: 5))
            line.addLine(to: CGPoint(x: 13.5, y: 5))

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

        case .menu:
            for y in [6.0, 10.0, 14.0] {
                line.move(to: CGPoint(x: 4, y: y))
                line.addLine(to: CGPoint(x: 16, y: y))
            }

        case .openEvent:
            capsule(x: 3, width: 14)

        case .previousEvent:
            run(arrows: 1, lobes: 1, goingLeft: true)

        case .nextEvent:
            run(arrows: 1, lobes: 1, goingLeft: false)
        }

        return (line, solid)
    }
}
