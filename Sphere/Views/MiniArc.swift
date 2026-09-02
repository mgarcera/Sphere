import SwiftUI

/// Today's arc, small.
///
/// Three timestamps make you do arithmetic to picture a day; the arc is the
/// picture. It also reads BETTER here than on the main screen: the main arc is
/// 24 hours across roughly eight screen widths, so locally it is nearly flat,
/// while squeezing the same day into a few hundred points turns it into a
/// proper hill.
///
/// It is anchored to the real now, not to the wheel, so it stays a reference
/// for the actual day however far the wheel has wandered.
struct MiniArc: View {
    let day: SolarDay
    /// Real current hour of day, 0..24.
    let nowHour: Double
    var height: CGFloat = 62

    private static let peak: CGFloat = 0.74
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

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(width: width, height: 1)
                    .position(x: width / 2, y: height)

                Curve(day: day, arcHeight: height, peak: Self.peak)
                    .stroke(Theme.ink, style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
                    .frame(width: width, height: height)

                ForEach(markers, id: \.label) { marker in
                    let point = Self.point(marker.hour, day: day, width: width, height: height)

                    Rectangle()
                        .fill(Theme.hairlineSoft)
                        .frame(width: 1, height: max(0, height - point.y))
                        .position(x: point.x, y: (height + point.y) / 2)

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
        CGPoint(
            x: width * (hour / 24),
            y: height - height * peak * day.normalizedElevation(atHour: hour)
        )
    }

    /// Its own geometry rather than ArcGeometry's, whose gutters and ceiling
    /// are tuned for the full-size arc and its sky band.
    private struct Curve: Shape {
        let day: SolarDay
        let arcHeight: CGFloat
        let peak: CGFloat

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let steps = 24 * 6
            for step in 0...steps {
                let hour = Double(step) / 6
                let point = CGPoint(
                    x: rect.minX + rect.width * (hour / 24),
                    y: rect.minY + arcHeight - arcHeight * peak * day.normalizedElevation(atHour: hour)
                )
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            return path
        }
    }
}
