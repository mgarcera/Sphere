import SwiftUI

/// The whole day drawn once, at full zoom width. Nothing here depends on
/// `focusHour`, so turning the wheel never re-samples the 288-point path — the
/// parent slides this layer with `.offset` instead. Keeping that true is what
/// makes the drag smooth; see `ArcWindow`.
struct ArcContent: View, Equatable {
    let day: SolarDay
    let width: CGFloat
    let height: CGFloat

    private var markers: [(hour: Double, label: String)] {
        var result: [(Double, String)] = []
        if let sunrise = day.sunrise { result.append((sunrise, "Sunrise")) }
        result.append((day.solarNoon, "Midday"))
        if let sunset = day.sunset { result.append((sunset, "Sunset")) }
        return result
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(width: width, height: 1)
                .position(x: width / 2, y: height)

            // Midnight. Days are drawn edge to edge, so this is the seam — the
            // curve itself runs straight through it, since the sun's elevation
            // really is continuous here.
            Rectangle()
                .fill(Theme.hairlineSoft)
                .frame(width: 1, height: height + 8)
                .position(x: 0, y: (height + 8) / 2)

            ForEach(0..<24) { hour in
                let x = width * (Double(hour) / 24)

                Rectangle()
                    .fill(Theme.hairline)
                    .frame(width: 1, height: 5)
                    .position(x: x, y: height + 3)

                Text(Self.hourLabel(Double(hour)))
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedLighter)
                    .fixedSize()
                    .position(x: x, y: height + 20)
            }

            DayArcShape(day: day)
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: width, height: height)

            ForEach(markers, id: \.label) { marker in
                let point = DayArcShape.point(
                    forHour: marker.hour,
                    day: day,
                    in: CGRect(x: 0, y: 0, width: width, height: height)
                )

                Circle()
                    .fill(Theme.ink)
                    .frame(width: 5, height: 5)
                    .position(point)

                Text(marker.label)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize()
                    .position(x: point.x, y: point.y - 16)
            }
        }
        .frame(width: width, height: height + Self.labelGutter, alignment: .topLeading)
    }

    /// Room below the baseline for the hour ticks and their labels.
    static let labelGutter: CGFloat = 32

    /// "6 AM", "12 PM" — hour 24 reads as midnight again.
    static func hourLabel(_ hour: Double) -> String {
        let h24 = Int(hour) % 24
        let h12 = h24 % 12 == 0 ? 12 : h24 % 12
        return "\(h12) \(h24 < 12 ? "AM" : "PM")"
    }

    /// "6:16 AM" — used for the readout above the dot.
    static func clock(_ hour: Double) -> String {
        let total = Int((hour * 60).rounded())
        let h24 = (total / 60) % 24
        let minute = total % 60
        let h12 = h24 % 12 == 0 ? 12 : h24 % 12
        return String(format: "%d:%02d %@", h12, minute, h24 < 12 ? "AM" : "PM")
    }
}
