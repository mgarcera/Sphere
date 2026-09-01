import SwiftUI

/// Step 1 of the build order: the whole day at once, static, so the curve's
/// shape can be judged before any interaction is layered on. The zoomed
/// three-hour window and the click wheel come next.
struct DayArcView: View {
    let day: SolarDay

    private var markers: [(hour: Double, label: String)] {
        var result: [(Double, String)] = []
        if let sunrise = day.sunrise { result.append((sunrise, "Sunrise")) }
        result.append((day.solarNoon, "Midday"))
        if let sunset = day.sunset { result.append((sunset, "Sunset")) }
        return result
    }

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                DayArcShape(day: day)
                    .stroke(Theme.ink, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                ForEach(markers, id: \.label) { marker in
                    let point = DayArcShape.point(forHour: marker.hour, day: day, in: rect)

                    Rectangle()
                        .fill(Theme.hairlineSoft)
                        .frame(width: 1, height: rect.maxY - point.y)
                        .position(x: point.x, y: (rect.maxY + point.y) / 2)

                    Circle()
                        .fill(Theme.ink)
                        .frame(width: 5, height: 5)
                        .position(point)

                    VStack(spacing: 1) {
                        Text(marker.label)
                            .foregroundStyle(Theme.muted)
                        Text(Self.clock(marker.hour))
                            .foregroundStyle(Theme.mutedLight)
                    }
                    .font(.footnote)
                    .fixedSize()
                    .position(x: point.x, y: point.y - 22)
                }
            }
        }
    }

    static func clock(_ hour: Double) -> String {
        let total = Int((hour * 60).rounded())
        let h24 = (total / 60) % 24
        let minute = total % 60
        let h12 = h24 % 12 == 0 ? 12 : h24 % 12
        return String(format: "%d:%02d %@", h12, minute, h24 < 12 ? "AM" : "PM")
    }
}
