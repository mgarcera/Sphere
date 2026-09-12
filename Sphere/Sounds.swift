import AVFoundation
import Foundation

/// The day's four moments, behind one switch.
///
/// Sphere had no sound on purpose — `Haptics` opens by saying so, and the click
/// exists because the wheel has no travel and nothing to hear. These are not a
/// second click. Each is a struck bell that marks a *place on the day*, not a
/// place on the wheel: you cross sunrise and sunrise rings, once, however fast
/// or slow you were turning when you got there.
///
/// That is the same rule `clickPastDetents` already follows — counted against
/// the hour rather than the gesture — and it is what keeps this from becoming a
/// texture. A whole day scrubbed end to end has at most four of these in it.
@MainActor
enum Sounds {
    static let key = "soundsEnabled"

    /// Off unless turned on, unlike haptics. A click is felt by one person; a
    /// bell is heard by the room, and an app that has never made a sound should
    /// not start making one in a meeting because it was updated.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? false
    }

    enum Moment: String, CaseIterable {
        case sunrise, midday, sunset, weather
    }

    /// One player each, never a shared one. The strikes run 6.7–7.5s and stay
    /// audible for about 4.5, so two crossings a few seconds apart overlap —
    /// which is what bells do. A single player would cut the first one off.
    private static var players: [Moment: AVAudioPlayer] = [:]

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
        for moment in Moment.allCases where players[moment] == nil {
            guard let url = Bundle.main.url(forResource: moment.rawValue, withExtension: "m4a"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[moment] = player
        }
    }

    static func play(_ moment: Moment) {
        guard isEnabled else { return }
        warm()
        guard let player = players[moment] else { return }
        // Restart rather than ignore: a second crossing of the same moment is a
        // real event, and the re-arm distance has already decided it is wanted.
        player.currentTime = 0
        player.play()
    }
}
