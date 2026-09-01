import SwiftUI

/// Shared drawing for both sky styles: the celestial body, cloud silhouettes
/// whose shape comes from real coverage, and precipitation.
///
/// Nothing here is randomised at draw time. Where a shape needs to look
/// hand-placed rather than stamped, it is perturbed by a hash of the day and
/// hour, so it is identical on every redraw and the sky does not shimmer while
/// the wheel turns.
enum SkyMarks {
    static let stroke = StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)

    /// Distance out along the arc's normal for each cloud deck. Altitude reads
    /// as height, which is the whole point of splitting coverage by layer.
    static let lowOffset: CGFloat = 30
    static let midOffset: CGFloat = 44
    static let highOffset: CGFloat = 57
    static let bodyOffset: CGFloat = 34

    /// Deterministic 0..1 from two integers.
    static func jitter(_ seed: Int, _ salt: Int) -> Double {
        var x = UInt64(bitPattern: Int64(seed &* 73_856_093) ^ Int64(salt &* 19_349_663))
        x ^= x >> 33
        x = x &* 0xff51_afd7_ed55_8ccd
        x ^= x >> 33
        return Double(x % 1_000) / 1_000
    }

    // MARK: - Clouds

    /// A cloud deck as a lobed silhouette. Coverage sets the width and how many
    /// lobes it breaks into, wind shears the top edge, and the seed nudges each
    /// lobe so no two hours draw the same outline.
    static func cloud(coverage: Double, wind: Double, seed: Int, salt: Int,
                      baseWidth: CGFloat, lobeHeight: CGFloat) -> Path {
        let coverage = min(max(coverage, 0), 1)
        let width = baseWidth * (0.55 + 0.75 * coverage)
        let lobes = max(2, Int((2 + coverage * 3).rounded()))
        let shear = CGFloat(min(wind / 45, 1)) * lobeHeight * 0.55

        var path = Path()
        let left = -width / 2
        let step = width / CGFloat(lobes)

        path.move(to: CGPoint(x: left, y: 0))
        for index in 0..<lobes {
            let wobble = CGFloat(jitter(seed, salt &+ index) - 0.5)
            let peak = lobeHeight * (0.72 + 0.5 * coverage) * (1 + wobble * 0.45)
            let x0 = left + step * CGFloat(index)
            let x1 = x0 + step
            let lean = shear * (CGFloat(index) / CGFloat(max(lobes - 1, 1)) - 0.5) * 2
            path.addCurve(
                to: CGPoint(x: x1, y: 0),
                control1: CGPoint(x: x0 + step * 0.15 + lean, y: -peak),
                control2: CGPoint(x: x1 - step * 0.15 + lean, y: -peak)
            )
        }
        path.addLine(to: CGPoint(x: left, y: 0))
        return path
    }

    /// High cloud is cirrus: no bulk, just streaks, and the wind lays them over.
    static func cirrus(coverage: Double, wind: Double, seed: Int, salt: Int,
                       baseWidth: CGFloat) -> Path {
        let coverage = min(max(coverage, 0), 1)
        let strands = max(2, Int((1 + coverage * 3).rounded()))
        let width = baseWidth * (0.6 + 0.8 * coverage)
        let lean = CGFloat(min(wind / 45, 1)) * 4

        var path = Path()
        for index in 0..<strands {
            let j = jitter(seed, salt &+ index &* 7)
            let y = CGFloat(index) * 4 - CGFloat(strands - 1) * 2
            let half = width / 2 * CGFloat(0.55 + 0.45 * j)
            let offset = CGFloat(j - 0.5) * width * 0.25
            path.move(to: CGPoint(x: -half + offset, y: y + lean * 0.3))
            path.addQuadCurve(
                to: CGPoint(x: half + offset, y: y - lean * 0.3),
                control: CGPoint(x: offset, y: y - 2.4)
            )
        }
        return path
    }

    // MARK: - Precipitation

    /// Strokes scale with how much actually falls, so drizzle and a downpour
    /// differ by more than which side of a category boundary they landed on.
    static func precipitation(_ amount: Double, frozen: Bool, seed: Int, salt: Int,
                              width: CGFloat) -> Path {
        guard amount > 0 else { return Path() }
        let intensity = min(amount / 4, 1)
        let count = max(2, Int((2 + intensity * 4).rounded()))
        let length = 4 + CGFloat(intensity) * 7

        var path = Path()
        for index in 0..<count {
            let j = CGFloat(jitter(seed, salt &+ index &* 13))
            let x = -width / 2 + width * (CGFloat(index) + 0.5) / CGFloat(count) + (j - 0.5) * 4
            let y = 3 + j * 2

            if frozen {
                let s = 2.0 + CGFloat(intensity)
                for k in 0..<3 {
                    let angle = Double(k) * .pi / 3
                    path.move(to: CGPoint(x: x - s * cos(angle), y: y + length * 0.4 - s * sin(angle)))
                    path.addLine(to: CGPoint(x: x + s * cos(angle), y: y + length * 0.4 + s * sin(angle)))
                }
            } else {
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x - 1.5, y: y + length))
            }
        }
        return path
    }

    static func bolt() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 1, y: 2))
        path.addLine(to: CGPoint(x: -4, y: 10))
        path.addLine(to: CGPoint(x: 0, y: 10))
        path.addLine(to: CGPoint(x: -5, y: 18))
        return path
    }

    // MARK: - Celestial body

    static func sun(radius: CGFloat) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        for index in 0..<8 {
            let angle = Double(index) * .pi / 4
            path.move(to: CGPoint(x: radius * 1.5 * cos(angle), y: radius * 1.5 * sin(angle)))
            path.addLine(to: CGPoint(x: radius * 2.2 * cos(angle), y: radius * 2.2 * sin(angle)))
        }
        return path
    }

    static func crescent(radius: CGFloat) -> Path {
        var path = Path()
        path.addArc(center: .zero, radius: radius,
                    startAngle: .degrees(300), endAngle: .degrees(120), clockwise: false)
        path.addArc(center: CGPoint(x: -radius * 0.55, y: 0), radius: radius * 1.05,
                    startAngle: .degrees(120), endAngle: .degrees(300), clockwise: true)
        return path
    }

    static func stars(seed: Int, salt: Int, spread: CGFloat) -> Path {
        var path = Path()
        for index in 0..<3 {
            let jx = CGFloat(jitter(seed, salt &+ index &* 31)) - 0.5
            let jy = CGFloat(jitter(seed, salt &+ index &* 57)) - 0.5
            let c = CGPoint(x: jx * spread, y: jy * spread * 0.6)
            let s: CGFloat = 1.8
            path.move(to: CGPoint(x: c.x - s, y: c.y))
            path.addLine(to: CGPoint(x: c.x + s, y: c.y))
            path.move(to: CGPoint(x: c.x, y: c.y - s))
            path.addLine(to: CGPoint(x: c.x, y: c.y + s))
        }
        return path
    }

    static func fogLines(width: CGFloat) -> Path {
        var path = Path()
        for index in 0..<2 {
            let y = CGFloat(index) * 4
            path.move(to: CGPoint(x: -width * 0.32 + CGFloat(index) * 3, y: y))
            path.addLine(to: CGPoint(x: width * 0.32 - CGFloat(index) * 3, y: y))
        }
        return path
    }
}
