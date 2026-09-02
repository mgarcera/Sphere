import SwiftUI

// TEMPORARY — icon direction study. Strip with the switcher in WheelSettings.
enum IconStyle: String, CaseIterable, Identifiable {
    case words, symbols, bespoke
    var id: String { rawValue }
    var title: String {
        switch self {
        case .words: "A · Words"
        case .symbols: "B · Symbols"
        case .bespoke: "C · Bespoke"
        }
    }
}

/// Hand-drawn marks in the arc's own line: 1.3 stroke, round caps, geometric,
/// no fill except where a dot is the point. Days are arcs here, the way they
/// are everywhere else in the app, so "next day" is an arc going right rather
/// than a calendar page.
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

        /// The day, as the arc draws it.
        func day(from x0: CGFloat, to x1: CGFloat, base: CGFloat, peak: CGFloat) {
            line.move(to: CGPoint(x: x0, y: base))
            line.addQuadCurve(to: CGPoint(x: x1, y: base),
                              control: CGPoint(x: (x0 + x1) / 2, y: peak))
        }

        func caret(at x: CGFloat, y: CGFloat, pointingLeft: Bool) {
            let reach: CGFloat = pointingLeft ? 3 : -3
            line.move(to: CGPoint(x: x + reach, y: y - 3))
            line.addLine(to: CGPoint(x: x, y: y))
            line.addLine(to: CGPoint(x: x + reach, y: y + 3))
        }

        switch action {
        case .none:
            line.move(to: CGPoint(x: 5, y: 10))
            line.addLine(to: CGPoint(x: 15, y: 10))

        case .now:
            // The arc with the time dot on it: the app's own signature.
            day(from: 3, to: 17, base: 14, peak: 3)
            solid.addEllipse(in: CGRect(x: 8, y: 6.5, width: 4, height: 4))

        case .calendar:
            // Successive days, which is what a calendar is here.
            day(from: 2, to: 7, base: 13, peak: 6)
            day(from: 7.5, to: 12.5, base: 13, peak: 6)
            day(from: 13, to: 18, base: 13, peak: 6)

        case .previousDay:
            day(from: 5, to: 17, base: 14, peak: 5)
            caret(at: 3, y: 14, pointingLeft: true)

        case .nextDay:
            day(from: 3, to: 15, base: 14, peak: 5)
            caret(at: 17, y: 14, pointingLeft: false)

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
            day(from: 2, to: 11, base: 15, peak: 8)
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

    /// The convention half of the study.
    static func symbolName(for action: WheelAction) -> String {
        switch action {
        case .none: "minus"
        case .now: "clock"
        case .calendar: "calendar"
        case .previousDay: "arrow.backward"
        case .nextDay: "arrow.forward"
        case .newAllDay: "calendar.badge.plus"
        case .appearance: "circle.lefthalf.filled"
        case .search: "magnifyingglass"
        case .openCalendarApp: "arrow.up.forward.app"
        case .muteHaptics: "waveform.slash"
        }
    }
}

/// One row's leading mark, in whichever style is being studied.
struct ActionGlyph: View {
    let action: WheelAction
    let style: IconStyle
    var color: Color = Theme.ink

    var body: some View {
        switch style {
        case .words:
            Color.clear.frame(width: 0, height: 20)
        case .symbols:
            Image(systemName: ActionMark.symbolName(for: action))
                .font(.system(size: 15, weight: .ultraLight))
                .foregroundStyle(color)
                .frame(width: 20, height: 20)
        case .bespoke:
            ActionMark(action: action, color: color)
        }
    }
}
