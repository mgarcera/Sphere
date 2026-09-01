import SwiftUI

/// Where the curve sits inside its box, in one place, because the shape, the
/// event capsules, the time dot and the sky band all have to agree on it.
enum ArcGeometry {
    /// The curve's ceiling. The top third of the box is left empty on purpose:
    /// that is the sky the weather band lives in, and it has to exist at every
    /// season, including midsummer noon when the sun is at its highest.
    ///
    /// The cost is that the summer-to-winter height difference now plays out
    /// over two thirds of the box rather than all of it.
    static let peakFraction: CGFloat = 0.65

    static func y(normalized: Double, height: CGFloat) -> CGFloat {
        height - height * peakFraction * normalized
    }
}
