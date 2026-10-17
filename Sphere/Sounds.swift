import AVFoundation
import Foundation

/// Four struck bells, one per press worth marking, behind one switch.
///
/// Sphere had no sound on purpose — `Haptics` opens by saying so, and the click
/// exists because a drag across the arc has no travel of its own and nothing to
/// hear. These are not a second click: the click is texture under every quarter
/// hour, and a bell is an event. (Until 2026-10-13 this said the wheel had no
/// travel. The wheel went in 2.0; the argument survived it, because a finger
/// sliding on glass is just as silent.)
///
/// They ring on **presses**, not on scrubbing. A press is already discrete and
/// already deliberate, which is what makes the whole question of how fast you
/// were moving go away — no crossing detection, no re-arm distance, no rate
/// gate. Dragging the arc stays silent.
@MainActor
enum Sounds {
    static let key = "soundsEnabled"

    /// Off unless turned on, unlike haptics. A click is felt by one person; a
    /// bell is heard by the room, and an app that has never made a sound should
    /// not start making one in a meeting because it was updated.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? false
    }

    /// Named for what it marks; the raw value is the file that marks it. The two
    /// were the same thing while these rang on solar crossings and are not any
    /// more, so the mapping lives here rather than at the call sites.
    ///
    /// Four bells, one per FUNCTION, and each doc below names every site it rings from.
    ///
    /// **A modal never rings (Mason, 2026-10-14).** A choice sheet is a question, and a bell marks
    /// what the answer does, so the hold's pair, the tap's pair, the event sheet and the corner's
    /// pair are all silent and the bell waits for the act. The four acts are: the menu opens, the
    /// view returns to now, an editor opens, the day picker opens. Nothing else in the app rings.
    ///
    /// This is close to where the set started on 2026-09-12, when every button did its thing
    /// directly and rang on doing it. The sheets arrived between, and each one that took a bell
    /// with it moved the sound one press earlier than the act — so the app announced a menu that
    /// might not open, and an editor that might turn out to be a question.
    ///
    /// The rule this set was built on held, and was applied where it had stopped being applied
    /// (Mason, 2026-10-13): "the chevrons are not among them: they are the one pair pressed
    /// repeatedly, and a bell on a button you hit five times in a row is the definition of
    /// obnoxious." The chevrons' successor, the edge bands, had become the only thing ringing
    /// `.calendar`, on every successful step. They are silent again, and `.calendar` is back on
    /// the day picker it was written for, so **all four ring, and no repeatedly-pressed control
    /// rings at all** — which is the arrangement the first commit to add these described:
    /// "menu -> sunrise, now -> sunset, editor -> midday, calendar -> weather, left / right ->
    /// silent" (2026-09-12). With the modals silenced on 2026-10-14 the set is back to exactly
    /// that, one bell per act, for the first time since the choice sheets arrived.
    enum Bell: String, CaseIterable {
        /// The menu opening, from the hold's Menu card or the corner's. Rang on the hold's
        /// QUESTION from 2026-10-10 until 2026-10-14, which meant it sounded whether or not the
        /// menu was the answer.
        case menu = "sunrise"
        /// Returning to now, from the corner button, through
        /// `goToNow`. Silent when already there, which is a no-op rather than an arrival.
        case now = "sunset"
        /// An editor opening, and only that. Five sites, every one of them an `editorTarget`
        /// assignment: New event and Open from the event sheet, New event from the time sheet, the
        /// header button when there is nothing under the dot, and an all-day row.
        ///
        /// It rang in `openEditor` and `openAtTappedHour` before either knew what it was about to
        /// do, so a tap that raised a question sounded exactly like a tap that opened an editor.
        case editor = "midday"
        /// The day picker opening, from either choice sheet's Pick date card. This is the surface
        /// it was built for: it rang on the wheel's CAL from 2026-09-12, lost that when `f456d51`
        /// moved the ring into `step` on 2026-10-10 as a side effect of the edge bands taking over
        /// stepping, and was given back on 2026-10-14. Mason remembered it before the code did.
        case calendar = "weather"
    }

    /// One player each, never a shared one. The strikes run 6.7–7.5s and stay
    /// audible for about 4.5, so two presses a few seconds apart overlap —
    /// which is what bells do. A single player would cut the first one off.
    private static var players: [Bell: AVAudioPlayer] = [:]

    /// `.ambient` is the whole posture: it obeys the ring/silent switch and
    /// mixes with whatever is already playing rather than ducking it. A
    /// decorative sound that interrupts someone's music is a bug, and one that
    /// ignores a silenced phone is worse.
    private static func activate() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
    }

    /// Decoding the first time a bell is struck would land it late enough to
    /// read as unrelated to the crossing, the same failure the haptic
    /// generators have when they go cold. Called once the setting is on.
    static func warm() {
        guard isEnabled else { return }
        activate()
        for bell in Bell.allCases where players[bell] == nil {
            guard let url = Bundle.main.url(forResource: bell.rawValue, withExtension: "m4a"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[bell] = player
        }
    }

    static func ring(_ bell: Bell) {
        guard isEnabled else { return }
        warm()
        guard let player = players[bell] else { return }
        // Restart rather than ignore. Two presses of the same button are two
        // events, and a press is deliberate enough that the second one is meant.
        player.currentTime = 0
        player.play()
    }
}
