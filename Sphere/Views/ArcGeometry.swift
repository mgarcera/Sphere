import SwiftUI

/// Where the curve sits inside its box, in one place, because the shape, the
/// event capsules, the time dot and the sky band all have to agree on it.
enum ArcGeometry {
    /// The curve's ceiling within the arc box. The top third is left empty on
    /// purpose so a sky exists at every season, midsummer noon included.
    ///
    /// The cost is that the summer-to-winter height difference plays out over
    /// two thirds of the box rather than all of it.
    static let peakFraction: CGFloat = 0.65

    /// Room ABOVE the box's ceiling. Without it the tallest clouds are cut off
    /// at the drawing layer's own top edge, which no amount of padding in the
    /// parent can reach: the clip is the canvas frame, not the window.
    static let skyGutter: CGFloat = 100

    /// How far below the baseline the curve can ever reach, as a fraction of the arc box
    /// (Mason, 2026-10-20). An asymptote rather than a value the curve attains: see
    /// `ArcCurve.drawn`. Derived from the shared ratio so this arc and the three smaller ones
    /// cannot drift; it works out to the 0.25 it was written as.
    ///
    /// Deliberately not `peakFraction`. A true mirror spends as much screen under the ground as
    /// over it, which shrinks the daylight half — the half with the events in it — to pay for a
    /// half nobody reads. A quarter is enough for the curve to visibly leave the horizon and
    /// come back, and it costs this much canvas and no more.
    static let nightFraction: CGFloat = peakFraction * CGFloat(ArcCurve.nightFloor)

    /// Room below the night's deepest point for the hour labels. The ticks and the day wedge
    /// stay ON the baseline, because that line is the timeline; only the labels clear the dip.
    static let labelGutter: CGFloat = 32

    /// Signed: 1 is the yearly noon, 0 the horizon, -1 the deepest midnight.
    static func y(normalized: Double, height: CGFloat) -> CGFloat {
        skyGutter + height - height * peakFraction * CGFloat(ArcCurve.drawn(normalized))
    }

    /// The horizon line, where elevation is zero.
    static func baseline(_ height: CGFloat) -> CGFloat { skyGutter + height }

    /// How far under the baseline the curve can reach.
    static func nightDepth(_ height: CGFloat) -> CGFloat { height * nightFraction }

    /// Where the hour labels sit: clear of the dip, so the curve passes between them and the
    /// timeline rather than through them.
    static func labelY(_ height: CGFloat) -> CGFloat { baseline(height) + nightDepth(height) + 16 }

    static func totalHeight(_ height: CGFloat) -> CGFloat {
        skyGutter + height + nightDepth(height) + labelGutter
    }
}
