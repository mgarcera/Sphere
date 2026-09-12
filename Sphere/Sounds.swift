import AVFoundation
import Foundation

/// Four struck bells, one per press worth marking, behind one switch.
///
/// Sphere had no sound on purpose — `Haptics` opens by saying so, and the click
/// exists because the wheel has no travel and nothing to hear. These are not a
/// second click: the click is texture under every quarter hour, and a bell is
/// an event.
///
/// They ring on **presses**, not on scrubbing. A press is already discrete and
/// already deliberate, which is what makes the whole question of how fast you
/// were moving go away — no crossing detection, no re-arm distance, no rate
/// gate. Turning the wheel stays silent.
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
    /// Three, not four. The chevrons are silent: they are the one pair pressed
    /// repeatedly, and a bell on a button you press five times in a row is the
    /// definition of obnoxious. `weather.m4a` stays in the bundle unused — it is
    /// the fourth of a set Mason made together, and the next thing worth marking
    /// should sound like its siblings rather than be commissioned alone.
    enum Bell: String, CaseIterable {
        /// Opening the menu.
        case menu = "sunrise"
        /// Returning to now.
        case now = "sunset"
        /// Opening the event modal — either the open/create choice or, with
        /// nothing under the dot, the new-event editor straight away.
        case editor = "midday"
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
