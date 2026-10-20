import SwiftUI

/// The day's sun-elevation curve as a `Shape`, sampled point by point — the
/// direct equivalent of the prototype's hand-built SVG `path` string.
///
/// `rect` spans the whole day: x maps hour 0 to 24 linearly, y maps an elevation of 0 to the
/// baseline, 1 to the curve's ceiling and -1 to the night's floor below the line.
struct DayArcShape: Shape {
    let day: SolarDay
    /// The arc box, not the frame. The frame carries a sky gutter above, and below the line the
    /// night's depth and the labels, so `rect.height` is not the curve's range.
    let arcHeight: CGFloat
    var samplesPerHour: Int = 12

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 24 * samplesPerHour

        for step in 0...steps {
            let hour = Double(step) / Double(samplesPerHour)
            let point = CGPoint(
                x: rect.minX + rect.width * (hour / 24),
                y: rect.minY + ArcGeometry.y(normalized: day.signedElevation(atHour: hour), height: arcHeight)
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}
