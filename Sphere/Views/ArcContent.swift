import SwiftUI

/// The whole day drawn once, at full zoom width. Nothing here depends on
/// `focusHour`, so turning the wheel never re-samples the 288-point path — the
/// parent slides this layer with `.offset` instead. Keeping that true is what
/// makes the drag smooth; see `ArcWindow`.
struct ArcContent: View, Equatable {
    let day: SolarDay
    let width: CGFloat
    let height: CGFloat
    /// One entry per hour we have weather for. Hours outside the forecast are
    /// simply absent, so an empty sky always means "not known" rather than
    /// "clear".
    var skyHours: [SkyHour] = []
    /// Seeds the deterministic wobble, so a shape is stable across redraws but
    /// different from its neighbour.
    var daySeed: Int = 0
    var cloudStyle: CloudStyle = .puffs

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(width: width, height: 1)
                .position(x: width / 2, y: ArcGeometry.baseline(height))

            // Midnight. Days are drawn edge to edge, so this is the seam — the
            // curve itself runs straight through it, since the sun's elevation
            // really is continuous here.
            Rectangle()
                .fill(Theme.hairlineSoft)
                .frame(width: 1, height: height + 8)
                .position(x: 0, y: ArcGeometry.baseline(height) - (height + 8) / 2 + 4)

            ForEach(0..<24) { hour in
                let x = width * (Double(hour) / 24)

                Rectangle()
                    .fill(Theme.hairline)
                    .frame(width: 1, height: 5)
                    .position(x: x, y: ArcGeometry.baseline(height) + 3)

                Text(Self.hourLabel(Double(hour)))
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedLighter)
                    .fixedSize()
                    .position(x: x, y: ArcGeometry.baseline(height) + 20)
            }

            // The sky band. Everything in it is placed along the curve's
            // normal and turned with its tangent, so the band runs parallel to
            // the arc rather than sitting in a flat row above it.
            SkyContinuous(hours: skyHours, daySeed: daySeed, style: cloudStyle,
                          pointsPerHour: width / 24, placement: skyPlacement(atHour:))
                .frame(width: width, height: ArcGeometry.totalHeight(height), alignment: .topLeading)

            DayArcShape(day: day, arcHeight: height)
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: width, height: ArcGeometry.totalHeight(height))

        }
        .frame(width: width, height: ArcGeometry.totalHeight(height), alignment: .topLeading)
    }

    /// How far out along the curve's normal the sky band sits.
    private static let skyOffset: CGFloat = 34

    private func skyPlacement(atHour hour: Double) -> (point: CGPoint, angle: Double) {
        let delta = 0.35
        func x(_ h: Double) -> CGFloat { width * (h / 24) }
        func y(_ h: Double) -> CGFloat {
            ArcGeometry.y(normalized: day.normalizedElevation(atHour: h), height: height)
        }

        let angle = atan2(y(hour + delta) - y(hour - delta), x(hour + delta) - x(hour - delta))
        // (sin, -cos) is the normal pointing away from the ground.
        return (
            CGPoint(
                x: x(hour) + sin(angle) * Self.skyOffset,
                y: y(hour) - cos(angle) * Self.skyOffset
            ),
            angle
        )
    }

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
