import UIKit

/// Feel, behind one switch.
///
/// The wheel is the one control with no travel and no sound, so a turn that
/// changes an hour otherwise reads only as the numbers above it changing. A
/// detent every quarter hour gives it the click the drawing implies: sixteen to
/// a rotation, which is close to the hardware it is borrowed from and far
/// enough apart to stay a texture rather than a buzz.
@MainActor
enum Haptics {
    static let key = "hapticsEnabled"

    /// On unless turned off, so the wheel has its click the first time it turns.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    /// A quarter hour per click. Held here rather than at the call site so the
    /// wheel and any later control share one spacing.
    static let detentHours = 0.25

    private static let detent = UIImpactFeedbackGenerator(style: .light)
    private static let refusal = UIImpactFeedbackGenerator(style: .rigid)

    /// Generators go cold in about a second, and a cold one fires late enough
    /// to feel detached from the thumb. Prepared on the way into a gesture and
    /// again after each click, so a continuous turn stays warm.
    static func warm() {
        guard isEnabled else { return }
        detent.prepare()
    }

    static func detentPassed() {
        guard isEnabled else { return }
        detent.impactOccurred(intensity: 0.55)
        detent.prepare()
    }

    /// Nothing in that direction. Heavier and blunter than a detent, so it
    /// reads as a wall rather than as one more click.
    static func nothingThere() {
        guard isEnabled else { return }
        refusal.impactOccurred(intensity: 0.8)
    }
}
