import SwiftUI

/// The click wheel, drawn in the same line as the arc and in the same grey as
/// the timeline's hour labels.
///
/// Every control on it is a plain tap on a printed word. Returning to now moved
/// to the arc itself, which retired the one gesture that could not be labelled. It is a control, not an object: the chrome
/// version was tried against this and removed, and the light grey keeps the
/// wheel from pulling weight away from the day above it.
///
/// Turning it is a rotation, not a swipe: the drag's angle around the centre is
/// what moves time, so a circling thumb keeps scrubbing indefinitely.
struct ClickWheel: View {
    /// Signed rotations, positive clockwise. One whole turn is one unit.
    let onRotate: (Double) -> Void
    /// Fires once when a turn starts, before any time moves.
    var onRotateBegan: () -> Void = {}
    let onMenu: () -> Void
    let onDate: () -> Void
    let onCentre: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    static let diameter: CGFloat = 280

    // Everything inside the wheel is a fraction of its diameter, so resizing it
    // is one number and the design holds its proportions.
    private static let buttonRatio: CGFloat = 0.383
    private static let labelInsetRatio: CGFloat = 0.108
    private static let hitTargetRatio: CGFloat = 0.192

    private static var buttonDiameter: CGFloat { diameter * buttonRatio }
    private static var labelInset: CGFloat { diameter * labelInsetRatio }
    /// Never below the 44pt floor, whatever the ratio works out to.
    private static var hitTarget: CGFloat { max(44, diameter * hitTargetRatio) }

    /// A real tap drifts a few points under the thumb. Anything under about ten
    /// was being read as the start of a turn, which is why the printed buttons
    /// took several attempts. Absolute, not scaled: it is about the thumb, not
    /// about the wheel.
    private static let scrubThreshold: CGFloat = 10

    private var outerRadius: CGFloat { Self.diameter / 2 }
    private var innerRadius: CGFloat { Self.buttonDiameter / 2 }

    /// Angle of the previous drag sample, in radians. Nil between drags.
    @State private var lastAngle: Double?

    private var line: Color { Theme.mutedLighter }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(line, lineWidth: 1.5)
                .contentShape(.circle)
                .gesture(
                    DragGesture(minimumDistance: Self.scrubThreshold)
                        .onChanged { value in
                            let dx = value.location.x - outerRadius
                            let dy = value.location.y - outerRadius
                            let radius = hypot(dx, dy)
                            // Ignore the dead zone over the centre button.
                            guard radius > innerRadius else { return }

                            let angle = atan2(dy, dx)
                            defer { lastAngle = angle }
                            // The first sample only sets the reference, so
                            // clearing the threshold never jumps time.
                            guard let previous = lastAngle else {
                                onRotateBegan()
                                return
                            }

                            var delta = angle - previous
                            // Unwrap across the ±π seam so one crossing isn't
                            // read as most of a turn in the wrong direction.
                            if delta > .pi { delta -= 2 * .pi }
                            if delta < -.pi { delta += 2 * .pi }

                            onRotate(delta / (2 * .pi))
                        }
                        .onEnded { _ in lastAngle = nil }
                )

            Button(action: onCentre) {
                Circle()
                    .strokeBorder(line, lineWidth: 1.5)
                    .frame(width: Self.buttonDiameter, height: Self.buttonDiameter)
                    .contentShape(.circle)
            }
            .buttonStyle(WheelButtonStyle())

            printedButton("MENU", action: onMenu)
                .position(x: outerRadius, y: Self.labelInset)

            printedButton("DATE", action: onDate)
                .position(x: outerRadius, y: Self.diameter - Self.labelInset)

            // These jump straight to the previous and next event's start. They
            // are not a generic time nudge — the wheel already does that.
            printedButton("‹", size: 20, action: onPrevious)
                .position(x: Self.labelInset, y: outerRadius)

            printedButton("›", size: 20, action: onNext)
                .position(x: Self.diameter - Self.labelInset, y: outerRadius)
        }
        .frame(width: Self.diameter, height: Self.diameter)
    }

    private func printedButton(_ text: String, size: CGFloat = 11, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: size, weight: size > 14 ? .medium : .semibold))
                .tracking(size > 14 ? 0 : 1.2)
                .foregroundStyle(line)
                .frame(width: Self.hitTarget, height: Self.hitTarget)
                .contentShape(.rect)
        }
        .buttonStyle(WheelButtonStyle())
    }
}

/// Presses dim rather than scale — the wheel is meant to read as one drawn
/// object, and a growing button would break that.
private struct WheelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.45 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
