import SwiftUI

/// The night: everything above the sun's own path, filled once.
///
/// The boundary is not near the curve, it IS the curve — the same elevation the
/// arc is drawn from, so the shape of the day is the shape of the night and no
/// horizontal edge exists anywhere on the screen.
///
/// **It lives inside the arc block**, which is what makes it one shape. Drawn at
/// screen level it needed to be told where the block was, and a reported
/// position is a thing that can be wrong — it was, and the fill stopped short of
/// the horizon. Here the coordinates are the block's own, so there is nothing to
/// measure and nothing to disagree with.
///
/// It reaches far above the block to cover the header, since the sky does not
/// stop at the top of the drawing. The type up there holds its own contrast
/// against whatever it is sitting on.
struct NightSky: View {
    /// 0 by day, 1 once the sun is properly down.
    let nightness: Double
    /// The curve box's height, and the hour at the centre of the window.
    let arcHeight: CGFloat
    let focusHour: Double
    let normalizedElevation: (Double) -> Double
    /// Weather takes precedence: night does not tint a storm.
    var suppressedBy: Double = 0

    static let colour = Color(red: 0.043, green: 0.055, blue: 0.098)

    /// How far above the block it reaches. Taller than any header on any phone;
    /// the excess costs nothing because it is one filled path.
    static let reach: CGFloat = 1400

    private var strength: Double { nightness * (1 - min(suppressedBy, 1)) }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            Canvas { context, _ in
                var path = Path()
                path.move(to: .zero)

                // The same sampling the arc uses, in the block's own
                // coordinates, so the fill's edge and the drawn curve are one
                // line rather than two that agree.
                let steps = 120
                for step in 0...steps {
                    let x = width * CGFloat(step) / CGFloat(steps)
                    let hour = focusHour + (Double(step) / Double(steps) - 0.5) * DayModel.windowHours
                    // Elevation clamps at zero, so through the night this is
                    // flat at the baseline: the night fills to the horizon and
                    // stops, because below the line is ground.
                    let y = Self.reach + ArcGeometry.y(normalized: normalizedElevation(hour),
                                                       height: arcHeight)
                    if step == 0 { path.addLine(to: CGPoint(x: 0, y: y)) }
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                path.addLine(to: CGPoint(x: width, y: 0))
                path.closeSubpath()
                context.fill(path, with: .color(Self.colour))
            }
        }
        .opacity(strength)
        .allowsHitTesting(false)
    }
}
