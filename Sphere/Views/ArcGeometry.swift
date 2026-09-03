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

    /// Room below the baseline for the hour ticks and their labels.
    static let labelGutter: CGFloat = 32

    static func y(normalized: Double, height: CGFloat) -> CGFloat {
        skyGutter + height - height * peakFraction * normalized
    }

    /// The horizon line, where elevation is zero.
    static func baseline(_ height: CGFloat) -> CGFloat { skyGutter + height }

    static func totalHeight(_ height: CGFloat) -> CGFloat { skyGutter + height + labelGutter }
}
