import SwiftUI

enum TimeChoice {
    case now
    case create
    case pickDate
}

/// What the arc offers when you point at a time that holds nothing: this moment, an event here,
/// or another day.
///
/// Three cards (Mason, 2026-10-10), and the same cards the New/Open sheet is built from. It
/// started as two on the hold alone — Now and Pick date — and gained Create when the single tap
/// was pointed at it, because a tap carries a time and creating there is the thing it was doing
/// before.
///
/// Was `HoldChoiceSheet` for one commit. The hold opened it, then the tap did too, and now the
/// tap is the only way in — the hold went back to the menu the same day, because a tap carries
/// the time these cards decide about and a long press reports no location at all. The name says
/// what it decides rather than which finger arrived, which is why it survived the move.
struct TimeChoiceSheet: View {
    let onChoose: (TimeChoice) -> Void

    static let height: CGFloat = ChoiceSheet<EmptyView>.height

    var body: some View {
        ChoiceSheet {
            // Now leads, as the one you reach for without thinking. New event is the middle
            // because it is the most common of the three and the thumb lands there. It reads
            // "New event" rather than "Create" so the two sheets name the same act the same way
            // (Mason, 2026-10-10).
            ChoiceCard(mark: .now, title: "Now") { onChoose(.now) }
            ChoiceCard(mark: .newEvent, title: "New event") { onChoose(.create) }
            ChoiceCard(mark: .calendar, title: "Pick date") { onChoose(.pickDate) }
        }
    }
}
