import SwiftUI

enum EventChoice {
    case open
    case create
    case pickDate
}

/// What happens when the thing you aimed at already holds an event.
///
/// Opening it was the only thing on offer, so an hour that already held
/// something could not have anything else put in it. Real days nest: a call
/// inside a block, a break inside a shift.
///
/// Two entry points, and as of 2026-10-14 they agree about WHICH event. The header title button
/// asks about the event under the dot and creates at the focus. A tap on the arc asks about the
/// event under the finger, and when the finger is not on one it falls back to the same event the
/// header is showing — Mason's rule: "if it's in the header, it should be able to be opened."
/// They still differ in where they CREATE, which is the point of the tap: the header creates at
/// the focus, the tap at the time under the finger. The caller carries both answers in; this
/// sheet only asks which.
///
/// Cards and nothing else. A heading and a caption under each were tried and cut: anything that
/// explains a one-word choice makes it look like a form. (This read "two buttons" until
/// 2026-10-13, which stopped being true when the third card arrived on 2026-10-10.)
///
/// Three cards since 2026-10-10. Aiming at an event and aiming at empty time are the same act
/// with a different thing under the finger, so the two sheets a tap can raise differ by one card
/// rather than by shape: this one is `TimeChoiceSheet` with Open inserted after New event.
///
/// That sentence read "the same three the other sheet offers but for Open in place of Now" until
/// 2026-10-13, and had been false since earlier the same day, when Now left the time sheet for
/// the hold and took that sheet down to two cards. The relationship survived the change; the
/// description of it did not.
struct EventChoiceSheet: View {
    let onChoose: (EventChoice) -> Void

    static let height: CGFloat = ChoiceSheet<EmptyView>.height

    var body: some View {
        ChoiceSheet { EventChoiceSheet.cards(onChoose: onChoose) }
    }

    /// Shared by the sheet and by `ChoicePanel`, so the two presentations cannot drift.
    @ViewBuilder
    static func cards(onChoose: @escaping (EventChoice) -> Void) -> some View {
            // New event leads (Mason, 2026-10-13), and Open, which had the position, takes the
            // middle. Open is the card that is about the thing you aimed at, which is why it led
            // from 2026-10-10, and what outranks that is position: a tap cannot tell you in
            // advance which of the two sheets it will raise, since that depends on whether the
            // finger happened to land on an event. So the card worth holding still is the one
            // both sheets share, and with New event first here and first in `TimeChoiceSheet`,
            // the leftmost card of a tap is the same thing either way. Open becomes what is
            // INSERTED when there was something there, which is also what it is.
            ChoiceCard(mark: .newEvent, title: "New event") { onChoose(.create) }
            ChoiceCard(mark: .openEvent, title: "Open") { onChoose(.open) }
            ChoiceCard(mark: .calendar, title: "Pick date") { onChoose(.pickDate) }
    }
}
