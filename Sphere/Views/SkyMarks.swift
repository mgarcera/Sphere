import SwiftUI

/// Shared drawing for the sky band.
///
/// Nothing here is randomised at draw time. Where a shape needs to look
/// hand-placed rather than stamped, it is perturbed by a hash of the day and
/// hour, so it is identical on every redraw and the sky does not shimmer while
/// the wheel turns.
enum SkyMarks {
    static let stroke = StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)
    static let heavyStroke = StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round)

    /// The sky is a co-equal element, not a backdrop: it holds the atmosphere
    /// half of the name while the capsules hold the work-and-social half. It
    /// stays distinguishable by register (ink, above the line) rather than by
    /// being quieter.
    static let inkOpacity: Double = 0.8

    /// Distance out along the arc's normal for each cloud deck. Altitude reads
    /// as height, which is why coverage is split by layer at all.
    static let lowOffset: CGFloat = 28
    static let midOffset: CGFloat = 50
    static let highOffset: CGFloat = 70

    /// Deterministic 0..1 from two integers.
    static func jitter(_ seed: Int, _ salt: Int) -> Double {
        var x = UInt64(bitPattern: Int64(seed &* 73_856_093) ^ Int64(salt &* 19_349_663))
        x ^= x >> 33
        x = x &* 0xff51_afd7_ed55_8ccd
        x ^= x >> 33
        return Double(x % 1_000) / 1_000
    }

    static func bolt(height: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 2, y: 0))
        path.addLine(to: CGPoint(x: -5, y: height * 0.5))
        path.addLine(to: CGPoint(x: 0.5, y: height * 0.5))
        path.addLine(to: CGPoint(x: -6, y: height))
        return path
    }

    static func fogLines(width: CGFloat) -> Path {
        var path = Path()
        for index in 0..<3 {
            let y = CGFloat(index) * 4
            let inset = CGFloat(index) * 3
            path.move(to: CGPoint(x: -width / 2 + inset, y: y))
            path.addLine(to: CGPoint(x: width / 2 - inset, y: y))
        }
        return path
    }
}
