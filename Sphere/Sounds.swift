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
    /// Four bells, and each doc below says where its one or two ring sites actually are, because
    /// three of the four had drifted by 2026-10-13 and a bell whose doc names the wrong surface
    /// is worse than an undocumented one.
    ///
    /// The rule this set was built on has inverted and is kept here as the thing to decide
    /// again: "the chevrons are not among them: they are the one pair pressed repeatedly, and a
    /// bell on a button you hit five times in a row is the definition of obnoxious." The
    /// chevrons' successor, the edge bands, is now the ONLY thing that rings `.calendar`, on
    /// every successful step. Either the rule was wrong or the edge bands should be silent.
    enum Bell: String, CaseIterable {
        /// The hold's question, `HoldChoiceSheet`. Rung from `onHold` and nowhere else; the menu
        /// itself opens silently, from the hold's Menu card and from the corner's. Named for the
        /// menu when the hold went straight there, which it has not since 2026-10-13.
        case menu = "sunrise"
        /// Returning to now, from the hold's Now card or from a two-finger tap, through
        /// `goToNow`. Silent when already there, which is a no-op rather than an arrival.
        case now = "sunset"
        /// Opening an editor or the choice that leads to one. Two ring sites: `openEditor`, where
        /// nothing under the dot means the new-event editor straight away, and `openAtTappedHour`,
        /// where nothing under the finger raises `TimeChoiceSheet` instead — not the editor, since
        /// 2026-10-10.
        case editor = "midday"
        /// An edge-band step to the next or previous event, rung from `step`. **Not** the day
        /// picker, which this said until 2026-10-13 and which rings nothing from either of the two
        /// places it opens.
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
