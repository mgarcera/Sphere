import SwiftUI

/// Today's arc, small.
///
/// Three timestamps make you do arithmetic to picture a day; the arc is the
/// picture. It also reads BETTER here than on the main screen: the main arc is
/// 24 hours across roughly eight screen widths, so locally it is nearly flat,
/// while squeezing the same day into a few hundred points turns it into a
/// proper hill.
///
/// It is anchored to the real now, not to the focus, so it stays a reference
/// for the actual day however far the arc has been dragged.
struct MiniArc: View {
    /// One event on the day, in the calendar's own colour — the same capsule
    /// the widgets draw, for the same reason: the arc is a picture of the day
    /// and the day has things in it.
    struct Span: Equatable {
        let hours: ClosedRange<Double>
        let color: Color
        let isCurrent: Bool
    }

    let day: SolarDay
    /// Real current hour of day, 0..24.
    let nowHour: Double
    var spans: [Span] = []
    var height: CGFloat = 62

    /// The hill was 0.74 of the box with nothing under the line. `ArcCurve.box` now splits the
    /// same box between the hill and the night, which costs the hill about a point at this size
    /// and makes this arc the same picture as the big one (Mason, 2026-10-21).
    private static let labelGutter: CGFloat = 17

    private var markers: [(hour: Double, label: String)] {
        var result: [(Double, String)] = []
        if let sunrise = day.sunrise { result.append((sunrise, ArcContent.clock(sunrise))) }
        result.append((day.solarNoon, ArcContent.clock(day.solarNoon)))
        if let sunset = day.sunset { result.append((sunset, ArcContent.clock(sunset))) }
        return result
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            // The night's deepest point lands exactly on `height`, so the labels below it keep
            // the gutter they had.
            let box = ArcCurve.box(height: height, inset: 0)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(width: width, height: 1)
                    .position(x: width / 2, y: box.baseline)

                Curve(day: day, baseline: box.baseline, peak: box.peak)
                    // Muted, not ink, and at the widgets' weight: the curve is
                    // what the day is drawn ON, and the capsules are what is on
                    // it. Drawing the ground in ink made it compete.
                    .stroke(Theme.mutedLight,
                            style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
                    .frame(width: width, height: height)

                // On the curve rather than beside it, at the two strengths the
                // rest of the app uses: full for the one happening now, held
                // back for the rest of the day.
                Canvas { context, _ in
                    for span in spans {
                        var path = Path()
                        let low = span.hours.lowerBound
                        let high = span.hours.upperBound
                        let steps = max(2, Int((high - low) * 6))
                        for step in 0...steps {
                            let hour = low + (high - low) * Double(step) / Double(steps)
                            let point = Self.point(hour, day: day, width: width, height: height)
                            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }
                        context.stroke(path,
                                       with: .color(span.color.opacity(span.isCurrent ? 1 : 0.72)),
                                       style: StrokeStyle(lineWidth: span.isCurrent ? 5 : 3.4,
                                                          lineCap: .round))
                    }
                }
                .frame(width: width, height: height)

                ForEach(markers, id: \.label) { marker in
                    let point = Self.point(marker.hour, day: day, width: width, height: height)

                    Rectangle()
                        .fill(Theme.hairlineSoft)
                        .frame(width: 1, height: abs(box.baseline - point.y))
                        .position(x: point.x, y: (box.baseline + point.y) / 2)

                    Circle()
                        .fill(Theme.muted)
                        .frame(width: 4, height: 4)
                        .position(point)

                    Text(marker.label)
                        .font(.caption2)
                        .foregroundStyle(Theme.mutedLight)
                        .monospacedDigit()
                        .fixedSize()
                        .position(x: min(max(point.x, 26), width - 26), y: height + 10)
                }

                // Where the real day has actually got to.
                Circle()
                    .fill(Theme.background)
                    .frame(width: 11, height: 11)
                    .position(Self.point(nowHour, day: day, width: width, height: height))
                Circle()
                    .fill(Theme.ink)
                    .frame(width: 6, height: 6)
                    .position(Self.point(nowHour, day: day, width: width, height: height))
            }
            .frame(width: width, height: height + Self.labelGutter, alignment: .topLeading)
        }
        .frame(height: height + Self.labelGutter)
    }

    static func point(_ hour: Double, day: SolarDay, width: CGFloat, height: CGFloat) -> CGPoint {
        let box = ArcCurve.box(height: height, inset: 0)
        return CGPoint(
            x: width * (hour / 24),
            y: box.baseline - box.peak * CGFloat(ArcCurve.drawn(day.signedElevation(atHour: hour)))
        )
    }

    /// Its own geometry rather than ArcGeometry's, whose gutters and ceiling
    /// are tuned for the full-size arc and its sky band.
    private struct Curve: Shape {
        let day: SolarDay
        /// Both in points, not fractions, so the split is worked out once by `ArcCurve.box`.
        let baseline: CGFloat
        let peak: CGFloat

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let steps = 24 * 6
            for step in 0...steps {
                let hour = Double(step) / 6
                let point = CGPoint(
                    x: rect.minX + rect.width * (hour / 24),
                    y: rect.minY + baseline
                        - peak * CGFloat(ArcCurve.drawn(day.signedElevation(atHour: hour)))
                )
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            return path
        }
    }
}
