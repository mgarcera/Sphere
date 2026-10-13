import SwiftUI

enum TimeChoice {
    case create
    case pickDate
}

/// What the arc offers when you point at a time that holds nothing: an event here, or another
/// day.
///
/// Was three cards and is two (Mason, 2026-10-13). Now led them, and it was the one card that
/// had nothing to do with the time under the finger: the other two act on the spot that was
/// aimed at, while Now throws that spot away and goes back to the present. A tap is an aim, so
/// the aimless choice left the aimed gesture and went to the hold, which reports no location
/// and never had anything to lose by it — see `HoldChoiceSheet`.
///
/// It started as two on the hold alone, Now and Pick date; gained Create when the single tap was
/// pointed at it; and is two again, with Create in place of Now. Was `HoldChoiceSheet` for one
/// commit in October 2026, which is now the name of the hold's own pair.
struct TimeChoiceSheet: View {
    let onChoose: (TimeChoice) -> Void

    static let height: CGFloat = ChoiceSheet<EmptyView>.height

    var body: some View {
        ChoiceSheet { TimeChoiceSheet.cards(onChoose: onChoose) }
    }

    /// Shared by the sheet and by `ChoicePanel`, so the two presentations cannot drift.
    @ViewBuilder
    static func cards(onChoose: @escaping (TimeChoice) -> Void) -> some View {
            // New event leads now that Now has gone: it is the most common of the two and the
            // thing the tap used to do on its own. It reads "New event" rather than "Create" so
            // the two sheets name the same act the same way (Mason, 2026-10-10).
            ChoiceCard(mark: .newEvent, title: "New event") { onChoose(.create) }
            ChoiceCard(mark: .calendar, title: "Pick date") { onChoose(.pickDate) }
    }
}
