import SwiftUI

/// Where the curve sits inside its box, in one place, because the shape, the
/// event capsules, the time dot and the sky band all have to agree on it.
struct ArcGeometry: Equatable {
    /// The curve's ceiling within the arc box. The top third is left empty on
    /// purpose so a sky exists at every season, midsummer noon included.
    ///
    /// The cost is that the summer-to-winter height difference plays out over
    /// two thirds of the box rather than all of it.
    var peakFraction: CGFloat = 0.65

    /// Room ABOVE the box's ceiling. Without it the tallest clouds are cut off
    /// at the drawing layer's own top edge, which no amount of padding in the
    /// parent can reach: the clip is the canvas frame, not the window.
    var skyGutter: CGFloat = 100

    /// Room below the baseline for the hour ticks and their labels.
    var labelGutter: CGFloat = 32

    /// The app's box, and the only one until a widget wanted the same drawing
    /// at a fraction of the size.
    static let app = ArcGeometry()

    func y(normalized: Double, height: CGFloat) -> CGFloat {
        skyGutter + height - height * peakFraction * normalized
    }

    /// The horizon line, where elevation is zero.
    func baseline(_ height: CGFloat) -> CGFloat { skyGutter + height }

    func totalHeight(_ height: CGFloat) -> CGFloat { skyGutter + height + labelGutter }

    // The app reads these off the type, which is what every call site said
    // before the box became a value.
    static func y(normalized: Double, height: CGFloat) -> CGFloat {
        app.y(normalized: normalized, height: height)
    }

    static func baseline(_ height: CGFloat) -> CGFloat { app.baseline(height) }

    static func totalHeight(_ height: CGFloat) -> CGFloat { app.totalHeight(height) }
}
