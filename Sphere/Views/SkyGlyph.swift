import SwiftUI

/// One small mark for a condition, for places that need to name the weather in
/// a word rather than draw it. The band draws the sky; this only labels it.
struct SkyGlyph: Shape {
    let condition: SkyCondition

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height

        func cloud(baseY: CGFloat) {
            path.move(to: CGPoint(x: w * 0.16, y: baseY))
            path.addCurve(to: CGPoint(x: w * 0.34, y: baseY - h * 0.30),
                          control1: CGPoint(x: w * 0.06, y: baseY - h * 0.14),
                          control2: CGPoint(x: w * 0.16, y: baseY - h * 0.30))
            path.addCurve(to: CGPoint(x: w * 0.66, y: baseY - h * 0.32),
                          control1: CGPoint(x: w * 0.46, y: baseY - h * 0.46),
                          control2: CGPoint(x: w * 0.58, y: baseY - h * 0.48))
            path.addCurve(to: CGPoint(x: w * 0.86, y: baseY),
                          control1: CGPoint(x: w * 0.86, y: baseY - h * 0.30),
                          control2: CGPoint(x: w * 0.94, y: baseY - h * 0.14))
            path.addLine(to: CGPoint(x: w * 0.16, y: baseY))
        }

        func sun(at centre: CGPoint, radius: CGFloat, rays: Bool) {
            path.addEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                                       width: radius * 2, height: radius * 2))
            guard rays else { return }
            for index in 0..<8 {
                let angle = Double(index) * .pi / 4
                path.move(to: CGPoint(x: centre.x + radius * 1.5 * cos(angle),
                                      y: centre.y + radius * 1.5 * sin(angle)))
                path.addLine(to: CGPoint(x: centre.x + radius * 2.2 * cos(angle),
                                         y: centre.y + radius * 2.2 * sin(angle)))
            }
        }

        func fall(count: Int, length: CGFloat, baseY: CGFloat) {
            for index in 0..<count {
                let x = w * (0.30 + CGFloat(index) * 0.20)
                path.move(to: CGPoint(x: x, y: baseY + h * 0.06))
                path.addLine(to: CGPoint(x: x - w * 0.05, y: baseY + h * 0.06 + length))
            }
        }

        switch condition {
        case .clear:
            sun(at: CGPoint(x: w / 2, y: h / 2), radius: w * 0.17, rays: true)
        case .partlyCloudy:
            sun(at: CGPoint(x: w * 0.66, y: h * 0.32), radius: w * 0.13, rays: true)
            cloud(baseY: h * 0.76)
        case .cloudy:
            cloud(baseY: h * 0.72)
        case .fog:
            cloud(baseY: h * 0.58)
            for index in 0..<2 {
                let y = h * (0.74 + CGFloat(index) * 0.16)
                path.move(to: CGPoint(x: w * (0.20 + CGFloat(index) * 0.08), y: y))
                path.addLine(to: CGPoint(x: w * (0.80 - CGFloat(index) * 0.06), y: y))
            }
        case .drizzle:
            cloud(baseY: h * 0.62)
            fall(count: 3, length: h * 0.12, baseY: h * 0.62)
        case .rain:
            cloud(baseY: h * 0.58)
            fall(count: 3, length: h * 0.24, baseY: h * 0.58)
        case .snow:
            cloud(baseY: h * 0.58)
            for index in 0..<3 {
                let c = CGPoint(x: w * (0.30 + CGFloat(index) * 0.20), y: h * 0.82)
                let s = w * 0.06
                for k in 0..<3 {
                    let angle = Double(k) * .pi / 3
                    path.move(to: CGPoint(x: c.x - s * cos(angle), y: c.y - s * sin(angle)))
                    path.addLine(to: CGPoint(x: c.x + s * cos(angle), y: c.y + s * sin(angle)))
                }
            }
        case .thunderstorm:
            cloud(baseY: h * 0.56)
            path.move(to: CGPoint(x: w * 0.56, y: h * 0.62))
            path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.82))
            path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.82))
            path.addLine(to: CGPoint(x: w * 0.34, y: h * 1.02))
        }
        return path
    }
}
