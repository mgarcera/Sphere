import SwiftUI

/// Small marks for the sun's three moments. Rise and set are the same half disc
/// on a horizon, told apart by which way the arrow points; midday is the whole
/// disc clear of it.
struct SunMark: Shape {
    enum Moment { case rise, noon, set }

    let moment: Moment

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let centre = CGPoint(x: w / 2, y: moment == .noon ? h * 0.5 : h * 0.66)
        let radius = w * (moment == .noon ? 0.26 : 0.28)

        if moment == .noon {
            path.addEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                                       width: radius * 2, height: radius * 2))
            for index in 0..<8 {
                let angle = Double(index) * .pi / 4
                path.move(to: CGPoint(x: centre.x + radius * 1.5 * cos(angle),
                                      y: centre.y + radius * 1.5 * sin(angle)))
                path.addLine(to: CGPoint(x: centre.x + radius * 2.1 * cos(angle),
                                         y: centre.y + radius * 2.1 * sin(angle)))
            }
            return path
        }

        // Half disc sitting on the horizon.
        path.addArc(center: centre, radius: radius,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.move(to: CGPoint(x: w * 0.08, y: centre.y))
        path.addLine(to: CGPoint(x: w * 0.92, y: centre.y))

        // The arrow is what separates rising from setting.
        let tip = moment == .rise ? h * 0.12 : h * 0.34
        let tail = moment == .rise ? h * 0.34 : h * 0.12
        path.move(to: CGPoint(x: centre.x, y: tail))
        path.addLine(to: CGPoint(x: centre.x, y: tip))
        path.move(to: CGPoint(x: centre.x - w * 0.11, y: tip + (moment == .rise ? w * 0.11 : -w * 0.11)))
        path.addLine(to: CGPoint(x: centre.x, y: tip))
        path.addLine(to: CGPoint(x: centre.x + w * 0.11, y: tip + (moment == .rise ? w * 0.11 : -w * 0.11)))

        return path
    }
}
