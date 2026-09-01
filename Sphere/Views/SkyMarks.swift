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

    /// A bolt with its zigs generated rather than fixed, so two strikes are
    /// never the same drawing. Roughly a third of them fork.
    /// A cluster of overlapping circles filling a band, back to front.
    ///
    /// Drawing each one filled-then-stroked in order is what keeps the arcs
    /// where puffs overlap: a circle in front paints over the one behind it,
    /// leaving exactly the visible portion. Unioning them into a single
    /// outline throws that away, and it is the whole look of a drawn cloud.
    /// `pointsPerHour` is required, not optional: radii are in points and the
    /// span is in hours, so without it the spacing is a unit mix-up and the
    /// puffs sit apart instead of overlapping.
    static func puffField(
        seed: Int, salt: Int,
        spanStart: Double, spanEnd: Double,
        baseOut: CGFloat, depth: CGFloat,
        radius: CGFloat, rows: Int,
        pointsPerHour: CGFloat,
        coverage: (Double) -> Double,
        place: (Double, CGFloat) -> CGPoint
    ) -> [(centre: CGPoint, radius: CGFloat, depth: CGFloat)] {
        var result: [(CGPoint, CGFloat, CGFloat)] = []
        var index = 0

        for row in 0..<rows {
            let rowT = rows == 1 ? 0 : Double(row) / Double(rows - 1)
            // Back rows sit higher and smaller, front rows lower and larger,
            // which is what gives the mass its depth.
            let rowOut = baseOut + depth * CGFloat(0.25 + 0.75 * rowT)
            let rowRadius = radius * CGFloat(0.72 + 0.4 * (1 - rowT))
            // Under one radius apart. The advance is jittered below, and the
            // radius roll can shrink a puff, so the nominal spacing has to
            // leave room for the worst of both or gaps open up.
            let stride = Double(rowRadius * 0.95 / pointsPerHour) * (1 + Double(rowT) * 0.15)

            var at = spanStart - stride * 0.5
            while at <= spanEnd + stride * 0.5 {
                let j1 = jitter(seed, salt &+ index &* 7)
                let j2 = jitter(seed, salt &+ index &* 13 &+ 401)
                let cover = coverage(min(max(at, spanStart), spanEnd))
                let r = rowRadius * CGFloat(0.6 + 0.5 * cover) * CGFloat(0.72 + 0.56 * j1)
                let out = rowOut + CGFloat(j2 - 0.5) * depth * 0.28
                result.append((place(at, out), r, out))
                at += stride * (0.8 + 0.3 * j1)
                index += 1
            }
        }
        // Furthest out is furthest back.
        return result.sorted { $0.2 > $1.2 }.map { (centre: $0.0, radius: $0.1, depth: $0.2) }
    }

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
