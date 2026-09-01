import SwiftUI

/// Shared drawing for the sky band.
///
/// Nothing here is randomised at draw time. Where a shape needs to look
/// hand-placed rather than stamped, it is perturbed by a hash of the day and
/// hour, so it is identical on every redraw and the sky does not shimmer while
/// the wheel turns.
enum SkyMarks {
    static let stroke = StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)

    /// The sky is a co-equal element, not a backdrop: it holds the atmosphere
    /// half of the name while the capsules hold the work-and-social half. It
    /// stays distinguishable by register (ink, above the line) rather than by
    /// being quieter.
    static let inkOpacity: Double = 0.8

    /// Distance out along the arc's normal for each cloud deck. Altitude reads
    /// as height, which is why coverage is split by layer at all.
    /// Absolute distance from the curve. These used to have a further 34pt
    /// added silently by the sky's placement helper, a leftover from when the
    /// band was per-hour icons at a fixed standoff, so every deck sat 34pt
    /// higher than its constant claimed and the clearance sums were all wrong.
    static let lowOffset: CGFloat = 62
    static let midOffset: CGFloat = 84
    static let highOffset: CGFloat = 104

    /// Deterministic 0..1 from two integers.
    static func jitter(_ seed: Int, _ salt: Int) -> Double {
        var x = UInt64(bitPattern: Int64(seed &* 73_856_093) ^ Int64(salt &* 19_349_663))
        x ^= x >> 33
        x = x &* 0xff51_afd7_ed55_8ccd
        x ^= x >> 33
        return Double(x % 1_000) / 1_000
    }

    /// A bolt with its zigs generated rather than fixed, so two strikes are
    /// never the same drawing. Roughly a third of them fork.
    static func bolt(height: CGFloat, seed: Int, salt: Int) -> Path {
        let zigs = 2 + Int((jitter(seed, salt) * 2).rounded())
        let step = height / CGFloat(zigs)
        var path = Path()

        var position = CGPoint(x: CGFloat(jitter(seed, salt &+ 11) - 0.5) * 3, y: 0)
        path.move(to: position)

        var side: CGFloat = jitter(seed, salt &+ 23) < 0.5 ? -1 : 1
        var forkFrom: CGPoint?

        for index in 0..<zigs {
            let spread = CGFloat(2.5 + jitter(seed, salt &+ index &* 31) * 4.5)
            // Each zig steps down and across, then cuts back, which is what
            // gives a bolt its kinked profile.
            let corner = CGPoint(x: position.x + side * spread, y: position.y + step * 0.55)
            path.addLine(to: corner)
            position = CGPoint(x: position.x + side * spread * 0.25, y: position.y + step)
            path.addLine(to: position)
            if index == zigs - 2 { forkFrom = position }
            side *= -1
        }

        if let forkFrom, jitter(seed, salt &+ 97) > 0.65 {
            path.move(to: forkFrom)
            path.addLine(to: CGPoint(x: forkFrom.x + side * 5, y: forkFrom.y + step * 0.7))
        }
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
