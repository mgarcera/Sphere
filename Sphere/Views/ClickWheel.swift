import SwiftUI

/// The iPod click wheel, in chrome and white. Colour is deliberately absent —
/// everything coloured on this screen belongs to the day, not to the control.
///
/// Turning it is a rotation, not a swipe: the drag's angle around the centre is
/// what moves time, so a circling thumb keeps scrubbing indefinitely.
struct ClickWheel: View {
    /// Signed rotations, positive clockwise. One whole turn is one unit.
    let onRotate: (Double) -> Void
    let onMenu: () -> Void
    let onNow: () -> Void
    let onCentre: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    static let diameter: CGFloat = 240
    private static let buttonDiameter: CGFloat = 92

    /// A real tap drifts a few points under the thumb. Anything under about ten
    /// was being read as the start of a turn, which is why the printed buttons
    /// took several attempts. A rotation travels far, so it loses nothing.
    private static let scrubThreshold: CGFloat = 10

    /// Below the 44pt floor a target is missed as often as it is hit, and every
    /// label here was smaller than that.
    private static let hitTarget: CGFloat = 46

    private var outerRadius: CGFloat { Self.diameter / 2 }
    private var innerRadius: CGFloat { Self.buttonDiameter / 2 }

    /// Angle of the previous drag sample, in radians. Nil between drags.
    @State private var lastAngle: Double?

    private let face = LinearGradient(
        colors: [Theme.Wheel.faceTop, Theme.Wheel.faceBottom],
        startPoint: .top,
        endPoint: .bottom
    )
    private let buttonFace = LinearGradient(
        colors: [Theme.Wheel.buttonTop, Theme.Wheel.buttonBottom],
        startPoint: .top,
        endPoint: .bottom
    )
    private let edge = Theme.Wheel.edge
    private let label = Theme.Wheel.label

    var body: some View {
        ZStack {
            Circle()
                .fill(face)
                .overlay(Circle().strokeBorder(edge, lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
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
                            guard let previous = lastAngle else { return }

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
                    .fill(buttonFace)
                    .overlay(Circle().strokeBorder(edge, lineWidth: 1))
                    .frame(width: Self.buttonDiameter, height: Self.buttonDiameter)
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
            }
            .buttonStyle(WheelButtonStyle())

            printedButton("MENU", action: onMenu)
                .position(x: outerRadius, y: 26)

            printedButton("NOW", action: onNow)
                .position(x: outerRadius, y: Self.diameter - 26)

            // These jump straight to the previous and next event's start. They
            // are not a generic time nudge — the wheel already does that.
            printedButton("‹", size: 20, action: onPrevious)
                .position(x: 26, y: outerRadius)

            printedButton("›", size: 20, action: onNext)
                .position(x: Self.diameter - 26, y: outerRadius)
        }
        .frame(width: Self.diameter, height: Self.diameter)
    }

    private func printedButton(_ text: String, size: CGFloat = 11, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: size, weight: size > 14 ? .medium : .semibold))
                .tracking(size > 14 ? 0 : 1.2)
                .foregroundStyle(label)
                .frame(width: Self.hitTarget, height: Self.hitTarget)
                .contentShape(.rect)
        }
        .buttonStyle(WheelButtonStyle())
    }
}

/// Presses dim rather than scale — the wheel is meant to read as a solid
/// object, and a growing button would break that.
private struct WheelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
