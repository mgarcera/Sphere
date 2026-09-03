import SwiftUI

/// Hand-drawn marks in the arc's own line: 1.3 stroke, round caps, geometric,
/// no fill except where a dot is the point.
///
/// Days are arcs here, the way they are everywhere else in the app: a whole arc
/// is a day, half of one is a point in it. The exceptions borrow universal
/// shapes where those read faster than restating the app's would — a grid of
/// dots for the calendar, a lens for looking at one moment closely.
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
    case menu, openEvent, newEvent, previousEvent, nextEvent
}

struct ActionMark: View {
    let mark: Mark
    var size: CGFloat = 20
    var color: Color = Theme.ink
    /// Rendered line width, held constant however large the mark is drawn.
    var stroke: CGFloat = 1.3

    /// Every path below is written in a 20-point box.
    private static let box: CGFloat = 20

    var body: some View {
        Canvas { context, _ in
            // Scaled, not merely framed. Without this the paths drew at their
            // literal 20-point coordinates inside whatever frame they were
            // given, so a 34-point mark sat small in the top-left corner of its
            // button rather than filling it.
            let scale = size / Self.box
            context.scaleBy(x: scale, y: scale)
            guard mark != .openEvent else {
                lens(&context, scale: scale)
                return
            }
            let (strokes, fills) = Self.paths(for: mark)
            // Divided by the scale, so the line reads the same weight at any
            // size instead of thickening with the drawing.
            context.stroke(strokes, with: .color(color),
                           style: StrokeStyle(lineWidth: stroke / scale,
                                              lineCap: .round, lineJoin: .round))
            context.fill(fills, with: .color(color))
        }
        .frame(width: size, height: size)
    }

    /// A magnifier over the day, refracted rather than merely circled.
    ///
    /// A ring drawn over an unchanged arc reads as a circle, because glass is
    /// recognised by what it does to what is behind it. So the arc inside is
    /// the arc redrawn through a ball lens.
    ///
    /// The mapping is the standard thin ball-lens one. A source point `d` from
    /// the centre appears at `r = R sin(n asin(d/R))` for refractive index `n`.
    /// Only the disc within `R sin(π/2n)` is visible through it, and that disc
    /// is spread across the whole lens, which is the magnification. Curvature
    /// grows toward the rim, so the arc bends as it approaches the edge and
    /// steps where it meets the arc outside. That step is the thing that says
    /// glass.
    private func lens(_ context: inout GraphicsContext, scale: CGFloat) {
        let line = StrokeStyle(lineWidth: stroke / scale, lineCap: .round, lineJoin: .round)
        let centre = CGPoint(x: 10, y: 9)
        let radius: CGFloat = 5.6
        // 2.0 rather than glass's 1.5: the icon is 20 points wide and the bend
        // has to survive that, so the lens is stronger than physical.
        let index: CGFloat = 2.0
        let visible = radius * sin(.pi / (2 * index))

        /// The day, as a quad from (1,16) to (19,16) through (10,2), solved
        /// rather than sampled from a Path so the refraction has real points.
        func day(_ t: CGFloat) -> CGPoint {
            CGPoint(x: 1 + 18 * t, y: 16 - 28 * t + 28 * t * t)
        }

        /// An event is a thick round-capped stroke ALONG the curve, which is
        /// how the arc itself draws one. A rounded rectangle beside it was a
        /// bar lying across the day rather than an event sitting on it.
        func run(from: CGFloat, to: CGFloat, map: (CGPoint) -> CGPoint?) -> Path {
            var path = Path()
            var drawing = false
            let steps = 120
            for step in 0...steps {
                let t = from + (to - from) * CGFloat(step) / CGFloat(steps)
                guard let point = map(day(t)) else { drawing = false; continue }
                if drawing { path.addLine(to: point) } else { path.move(to: point); drawing = true }
            }
            return path
        }

        /// Where a source point appears through a ball lens. Nil outside the
        /// disc the glass can actually show.
        func refract(_ point: CGPoint) -> CGPoint? {
            let dx = point.x - centre.x
            let dy = point.y - centre.y
            let distance = hypot(dx, dy)
            guard distance <= visible else { return nil }
            guard distance > 0 else { return point }
            let mapped = radius * sin(index * asin(distance / radius))
            let factor = mapped / distance
            return CGPoint(x: centre.x + dx * factor, y: centre.y + dy * factor)
        }

        let bounds = CGRect(x: centre.x - radius, y: centre.y - radius,
                            width: radius * 2, height: radius * 2)
        // Widths as multiples of the drawn line, so the family holds at any size.
        let thin = stroke * 2.4 / scale

        var arc = Path()
        arc.move(to: day(0))
        arc.addQuadCurve(to: day(1), control: CGPoint(x: 10, y: 2))
        context.stroke(arc, with: .color(color), style: line)

        // The event runs out past the glass on both sides, so the thin part
        // outside sits next to the fat part inside. Without that there is
        // nothing to compare the magnified size against.
        context.stroke(run(from: 0.13, to: 0.87) { $0 }, with: .color(color),
                       style: StrokeStyle(lineWidth: thin, lineCap: .round))

        // Clear the glass before drawing through it, or the unrefracted day
        // shows behind its own magnified copy.
        context.fill(Path(ellipseIn: bounds), with: .color(Theme.background))

        context.stroke(run(from: 0, to: 1, map: refract), with: .color(color), style: line)

        // The same event, refracted point by point rather than scaled, so it
        // follows the bend instead of sitting straight across it. It reaches
        // the rim and the clip cuts it there, which is what a lens shows of
        // something longer than its field.
        context.drawLayer { glass in
            glass.clip(to: Path(ellipseIn: bounds))
            glass.stroke(run(from: 0.13, to: 0.87, map: refract), with: .color(color),
                         style: StrokeStyle(lineWidth: thin * index, lineCap: .round))
        }

        context.stroke(Path(ellipseIn: bounds), with: .color(color), style: line)
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
            break   // drawn by `lens`, which needs ordered layers

        case .newEvent:
            // The same day the lens draws, with a plus set INTO it rather than
            // floating above it. Above the line is the all-day mark, which is
            // about the whole day; on the line is about a moment in it.
            //
            // The arc breaks around the plus. At the crest the curve is flat,
            // so a plus laid over it would have its horizontal arm collinear
            // with the line and read as a tick rather than a plus.
            func day(_ t: CGFloat) -> CGPoint {
                CGPoint(x: 1 + 18 * t, y: 16 - 28 * t + 28 * t * t)
            }
            func segment(_ from: CGFloat, _ to: CGFloat) {
                line.move(to: day(from))
                for step in 1...40 {
                    line.addLine(to: day(from + (to - from) * CGFloat(step) / 40))
                }
            }
            segment(0, 0.30)
            segment(0.70, 1)

            let crest = day(0.5)
            line.move(to: CGPoint(x: crest.x, y: crest.y - 2.8))
            line.addLine(to: CGPoint(x: crest.x, y: crest.y + 2.8))
            line.move(to: CGPoint(x: crest.x - 2.8, y: crest.y))
            line.addLine(to: CGPoint(x: crest.x + 2.8, y: crest.y))

        case .previousEvent:
            run(arrows: 1, lobes: 1, goingLeft: true)

        case .nextEvent:
            run(arrows: 1, lobes: 1, goingLeft: false)
        }

        return (line, solid)
    }
}
