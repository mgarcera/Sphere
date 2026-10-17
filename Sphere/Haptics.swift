import UIKit

/// Feel, behind one switch.
///
/// Dragging the arc has no travel and no sound, so a drag that changes an hour
/// otherwise reads only as the numbers above it changing. A detent every quarter
/// hour gives it a click: far enough apart to stay a texture rather than a buzz.
///
/// Written for the wheel, which is where "sixteen to a rotation, close to the
/// hardware it is borrowed from" came from, and rewritten 2026-10-13 because
/// there is no rotation left to count sixteen of. The spacing did not change
/// with the control; a quarter hour is still the unit, now measured in points
/// dragged rather than in degrees turned.
@MainActor
enum Haptics {
    static let key = "hapticsEnabled"

    /// On unless turned off, so the arc has its click the first time it is dragged.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    /// A quarter hour per click. Held here rather than at the call site so the drag and any
    /// later control share one spacing, which is the reason it survived the wheel.
    static let detentHours = 0.25

    private static let detent = UIImpactFeedbackGenerator(style: .light)
    private static let arrival = UIImpactFeedbackGenerator(style: .medium)
    private static let refusal = UIImpactFeedbackGenerator(style: .rigid)

    /// Generators go cold in about a second, and a cold one fires late enough
    /// to feel detached from the thumb. Prepared on the way into a gesture and
    /// again after each click, so a continuous drag stays warm.
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
    /// the corner button, a day picked. Weightier than a detent, since a jump crosses in one press
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

    // A `held()` lived here until 2026-10-13: an 0.45s arrival at intensity 0.45, to say a long
    // press had registered before its action landed. It had zero call sites in the app and its
    // own comment claimed to be "the only thing that says the gesture took", which nothing was.
    // Mason's call to delete rather than wire it: the hold's answer is a sheet, and a sheet
    // arriving is the report. Restoring it is `arrival.impactOccurred(intensity: 0.45)` behind
    // the `isEnabled` guard the others use.

    /// Nothing in that direction. Blunter than an arrival and sharper than a
    /// detent, so it reads as a wall rather than as either.
    static func nothingThere() {
        guard isEnabled else { return }
        refusal.impactOccurred(intensity: 0.8)
    }
}
