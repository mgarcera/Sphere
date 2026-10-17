import SwiftUI

enum TimeChoice {
    case create
    case pickDate
}

/// What the arc offers when you point at a time that holds nothing: an event here, or another
/// day.
///
/// Two cards, and both of them are about the time under the finger. That is the whole argument
/// for which cards a tap gets: a tap is an aim, and a card that discards the aimed time does not
/// belong on it. New event uses that time. Pick date changes which day it is in. Now threw it
/// away, which is why Now is gone from here as of 2026-10-16.
///
/// Now went to a button of its own in the corner opposite the "?", visible only when the focus
/// has left the present (`nowButton` in `ContentView`, which holds that argument). That corner
/// is the only route as of 2026-10-16: the two-finger tap went the same day, so the present is
/// reached by one visible control instead of by a card and a hidden gesture.
///
/// **The invariant this gives up.** Until today both tap sheets read New event, something, Pick
/// date, with the something being Now when there was no event and Open when there was — so the
/// leftmost card of a tap was the same thing either way and the order never moved. That is over:
/// this sheet is two cards and `EventChoiceSheet` is three. What survives is the part that was
/// doing the work, which is that New event leads both and Pick date closes both. Open is now
/// literally what is INSERTED when there was something there, rather than a substitution.
///
/// Now's route has moved four times in six days: the hold, then back here, then its own button.
/// The reason it kept moving is in each of those commits; the reason it stopped is that it is the
/// one act here that has no position, and a button has no position either.
struct TimeChoiceSheet: View {
    let onChoose: (TimeChoice) -> Void

    static let height: CGFloat = ChoiceSheet<EmptyView>.height

    var body: some View {
        ChoiceSheet { TimeChoiceSheet.cards(onChoose: onChoose) }
    }

    /// Shared by the sheet and by `ChoicePanel`, so the two presentations cannot drift.
    @ViewBuilder
    static func cards(onChoose: @escaping (TimeChoice) -> Void) -> some View {
            // New event leads: it is the thing the tap used to do on its own, and it is the one
            // that uses the time under the finger. It reads "New event" rather than "Create" so
            // both tap sheets name the same act the same way (Mason, 2026-10-10).
            ChoiceCard(mark: .newEvent, title: "New event") { onChoose(.create) }
            ChoiceCard(mark: .calendar, title: "Pick date") { onChoose(.pickDate) }
    }
}
