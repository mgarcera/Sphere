import SwiftUI

/// One hour of sky, drawn in the same weight of line as everything else.
/// Nothing is filled and nothing is coloured, so the band reads as part of the
/// same drawing as the arc rather than as a widget sitting on top of it.
struct WeatherIcon: View {
    let condition: SkyCondition
    let isDaylight: Bool
    var size: CGFloat = 15

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            let stroke = GraphicsContext.Shading.color(Theme.ink.opacity(0.55))
            let style = StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)

            for path in Self.paths(for: condition, isDaylight: isDaylight, in: rect) {
                context.stroke(path, with: stroke, style: style)
            }
        }
        .frame(width: size * 1.6, height: size * 1.6)
    }

    static func paths(for condition: SkyCondition, isDaylight: Bool, in rect: CGRect) -> [Path] {
        switch condition {
        case .clear:
            return isDaylight ? [sun(in: rect)] : [crescent(in: rect), stars(in: rect)]
        case .partlyCloudy:
            return [smallBody(in: rect, isDaylight: isDaylight), cloud(in: rect, low: true)]
        case .cloudy:
            return [cloud(in: rect, low: false)]
        case .fog:
            return [cloud(in: rect, low: true), fogLines(in: rect)]
        case .drizzle:
            return [cloud(in: rect, low: true), fall(in: rect, count: 2, length: 0.10)]
        case .rain:
            return [cloud(in: rect, low: true), fall(in: rect, count: 3, length: 0.16)]
        case .snow:
            return [cloud(in: rect, low: true), flakes(in: rect)]
        case .thunderstorm:
            return [cloud(in: rect, low: true), bolt(in: rect)]
        }
    }

    // MARK: - Parts

    private static func cloud(in rect: CGRect, low: Bool) -> Path {
        let w = rect.width, h = rect.height
        let baseY = low ? h * 0.60 : h * 0.66
        let left = w * 0.18, right = w * 0.82
        var path = Path()
        path.move(to: CGPoint(x: left, y: baseY))
        path.addCurve(to: CGPoint(x: w * 0.34, y: h * 0.34),
                      control1: CGPoint(x: w * 0.10, y: h * 0.46),
                      control2: CGPoint(x: w * 0.18, y: h * 0.32))
        path.addCurve(to: CGPoint(x: w * 0.63, y: h * 0.30),
                      control1: CGPoint(x: w * 0.44, y: h * 0.20),
                      control2: CGPoint(x: w * 0.58, y: h * 0.18))
        path.addCurve(to: CGPoint(x: right, y: baseY),
                      control1: CGPoint(x: w * 0.84, y: h * 0.34),
                      control2: CGPoint(x: w * 0.90, y: h * 0.52))
        path.addLine(to: CGPoint(x: left, y: baseY))
        return path
    }

    private static func sun(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let inner = rect.width * 0.17
        var path = Path()
        path.addEllipse(in: CGRect(x: centre.x - inner, y: centre.y - inner,
                                   width: inner * 2, height: inner * 2))
        for index in 0..<8 {
            let angle = Double(index) * .pi / 4
            path.move(to: CGPoint(x: centre.x + inner * 1.45 * cos(angle),
                                  y: centre.y + inner * 1.45 * sin(angle)))
            path.addLine(to: CGPoint(x: centre.x + inner * 2.15 * cos(angle),
                                     y: centre.y + inner * 2.15 * sin(angle)))
        }
        return path
    }

    private static func crescent(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX + rect.width * 0.05, y: rect.midY)
        let r = rect.width * 0.24
        var path = Path()
        path.addArc(center: centre, radius: r,
                    startAngle: .degrees(300), endAngle: .degrees(120), clockwise: false)
        path.addArc(center: CGPoint(x: centre.x - r * 0.55, y: centre.y), radius: r * 1.05,
                    startAngle: .degrees(120), endAngle: .degrees(300), clockwise: true)
        return path
    }

    private static func stars(in rect: CGRect) -> Path {
        var path = Path()
        for point in [CGPoint(x: 0.20, y: 0.28), CGPoint(x: 0.26, y: 0.66), CGPoint(x: 0.78, y: 0.74)] {
            let c = CGPoint(x: rect.width * point.x, y: rect.height * point.y)
            let s = rect.width * 0.045
            path.move(to: CGPoint(x: c.x - s, y: c.y))
            path.addLine(to: CGPoint(x: c.x + s, y: c.y))
            path.move(to: CGPoint(x: c.x, y: c.y - s))
            path.addLine(to: CGPoint(x: c.x, y: c.y + s))
        }
        return path
    }

    /// The sun or moon peeking out behind a cloud.
    private static func smallBody(in rect: CGRect, isDaylight: Bool) -> Path {
        let centre = CGPoint(x: rect.width * 0.66, y: rect.height * 0.30)
        let r = rect.width * 0.14
        var path = Path()
        if isDaylight {
            path.addArc(center: centre, radius: r,
                        startAngle: .degrees(200), endAngle: .degrees(20), clockwise: false)
            for index in 0..<4 {
                let angle = -.pi * 0.85 + Double(index) * .pi / 4.4
                path.move(to: CGPoint(x: centre.x + r * 1.4 * cos(angle), y: centre.y + r * 1.4 * sin(angle)))
                path.addLine(to: CGPoint(x: centre.x + r * 2.0 * cos(angle), y: centre.y + r * 2.0 * sin(angle)))
            }
        } else {
            path.addArc(center: centre, radius: r,
                        startAngle: .degrees(200), endAngle: .degrees(20), clockwise: false)
        }
        return path
    }

    private static func fall(in rect: CGRect, count: Int, length: CGFloat) -> Path {
        var path = Path()
        for index in 0..<count {
            let x = rect.width * (0.32 + CGFloat(index) * 0.18)
            let y = rect.height * 0.70
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - rect.width * 0.04, y: y + rect.height * length))
        }
        return path
    }

    private static func flakes(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<3 {
            let c = CGPoint(x: rect.width * (0.32 + CGFloat(index) * 0.18), y: rect.height * 0.78)
            let s = rect.width * 0.05
            for k in 0..<3 {
                let angle = Double(k) * .pi / 3
                path.move(to: CGPoint(x: c.x - s * cos(angle), y: c.y - s * sin(angle)))
                path.addLine(to: CGPoint(x: c.x + s * cos(angle), y: c.y + s * sin(angle)))
            }
        }
        return path
    }

    private static func fogLines(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<2 {
            let y = rect.height * (0.74 + CGFloat(index) * 0.12)
            path.move(to: CGPoint(x: rect.width * (0.26 + CGFloat(index) * 0.06), y: y))
            path.addLine(to: CGPoint(x: rect.width * (0.76 - CGFloat(index) * 0.04), y: y))
        }
        return path
    }

    private static func bolt(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.54, y: rect.height * 0.64))
        path.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.84))
        path.addLine(to: CGPoint(x: rect.width * 0.53, y: rect.height * 0.84))
        path.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.height * 1.02))
        return path
    }
}
