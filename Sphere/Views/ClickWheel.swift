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
    let onCentre: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    static let diameter: CGFloat = 240
    private static let buttonDiameter: CGFloat = 92

    private var outerRadius: CGFloat { Self.diameter / 2 }
    private var innerRadius: CGFloat { Self.buttonDiameter / 2 }

    /// Angle of the previous drag sample, in radians. Nil between drags.
    @State private var lastAngle: Double?

    private let face = LinearGradient(
        colors: [Color(white: 0.99), Color(white: 0.93)],
        startPoint: .top,
        endPoint: .bottom
    )
    private let buttonFace = LinearGradient(
        colors: [Color(white: 1.0), Color(white: 0.96)],
        startPoint: .top,
        endPoint: .bottom
    )
    private let edge = Color(white: 0.86)
    private let label = Color(white: 0.60)

    var body: some View {
        ZStack {
            Circle()
                .fill(face)
                .overlay(Circle().strokeBorder(edge, lineWidth: 1))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
                .contentShape(.circle)
                // minimumDistance keeps a stationary tap available to the MENU
                // button stacked above; anything past a couple of points is a turn.
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            let dx = value.location.x - outerRadius
                            let dy = value.location.y - outerRadius
                            let radius = hypot(dx, dy)
                            // Ignore the dead zone over the centre button.
                            guard radius > innerRadius else { return }

                            let angle = atan2(dy, dx)
                            defer { lastAngle = angle }
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

            Button(action: onMenu) {
                Text("MENU")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(label)
                    .padding(8)
            }
            .buttonStyle(WheelButtonStyle())
            .position(x: outerRadius, y: 26)

            // These jump straight to the previous and next task's hour. They
            // are not a generic time nudge — the wheel already does that.
            Button(action: onPrevious) {
                Text("‹")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(label)
                    .padding(10)
            }
            .buttonStyle(WheelButtonStyle())
            .position(x: 26, y: outerRadius)

            Button(action: onNext) {
                Text("›")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(label)
                    .padding(10)
            }
            .buttonStyle(WheelButtonStyle())
            .position(x: Self.diameter - 26, y: outerRadius)
        }
        .frame(width: Self.diameter, height: Self.diameter)
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
