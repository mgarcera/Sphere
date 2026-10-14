import SwiftUI

enum TimeChoice {
    case create
    case now
    case pickDate
}

/// What the arc offers when you point at a time that holds nothing: an event here, the present,
/// or another day.
///
/// Three cards, and the middle one is the variable: this sheet and `EventChoiceSheet` both read
/// New event, something, Pick date, and the something is **Now when there is no event and Open
/// when there is** (Mason, 2026-10-14). So a tap always offers three cards in the same order, and
/// the only thing that changes is whether the middle one takes you to the present or into the
/// thing you are already on.
///
/// Now has been here, left, and come back inside two days. On 2026-10-13 it went to the hold on
/// the argument that a tap is an aim and Now throws the aimed spot away; the hold reported no
/// position and had nothing to lose. That is still true about the gesture and lost anyway, because
/// the hold now carries the guide and the menu, and because Now is reached far more often than it
/// is reasoned about. Two fingers still go straight to it for anyone who does not want the card.
///
/// It started as two on the hold alone, Now and Pick date; gained Create when the single tap was
/// pointed at it; lost Now; and is three.
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
            // of the three that uses the time under the finger. It reads "New event" rather than
            // "Create" so both tap sheets name the same act the same way (Mason, 2026-10-10).
            // Now takes the middle slot, where `EventChoiceSheet` puts Open.
            ChoiceCard(mark: .newEvent, title: "New event") { onChoose(.create) }
            ChoiceCard(mark: .now, title: "Now") { onChoose(.now) }
            ChoiceCard(mark: .calendar, title: "Pick date") { onChoose(.pickDate) }
    }
}
