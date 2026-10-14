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
    private static let arrival = UIImpactFeedbackGenerator(style: .medium)
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

    /// The dot jumped somewhere: an edge band stepping to an event, Now from the hold or from
    /// two fingers, a day picked. Weightier than a detent, since a jump crosses in one press
    /// what a scrub would take a long drag to cover.
    ///
    /// Rewritten 2026-10-13. It named a chevron, a tap that returned to now, and what the wheel
    /// would take several turns to cover; the chevrons and the wheel went in 2.0 and the tap
    /// gave Now up on 2026-10-10, so all three examples described controls that do not exist.
    /// The four jumps it reports are every caller of `travel` in `ContentView`.
    static func moved() {
        guard isEnabled else { return }
        arrival.impactOccurred(intensity: 0.7)
    }

    /// A long press registered. Nothing about a hold is visible while it is
    /// happening, so this is the only thing that says the gesture took before
    /// the action itself lands.
    ///
    /// NOT CALLED as of 2026-10-13, and nothing else reports the hold either: grep found zero
    /// `.held()` call sites in the app. The hold's feedback is `Sounds.ring(.menu)` and the
    /// sheet arriving, both of which land after the gesture completes rather than when it
    /// registers. Kept rather than deleted because the question is whether the hold SHOULD
    /// announce itself at 0.45s, which is Mason's to answer; if the answer is no, this goes.
    static func held() {
        guard isEnabled else { return }
        arrival.impactOccurred(intensity: 0.45)
    }

    /// Nothing in that direction. Blunter than an arrival and sharper than a
    /// detent, so it reads as a wall rather than as either.
    static func nothingThere() {
        guard isEnabled else { return }
        refusal.impactOccurred(intensity: 0.8)
    }
}
