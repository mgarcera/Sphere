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
/// Was `HoldChoiceSheet` for one commit. Renamed because the hold is no longer the only way in:
/// a tap on empty time opens it too, and the name of a sheet should say what it decides rather
/// than which finger arrived.
///
/// The hold and the tap differ in one thing, and the caller resolves it: a tap knows the time
/// under the finger, a hold does not, so a held Create starts at the focus — the time under the
/// dot, in the middle of the screen.
struct TimeChoiceSheet: View {
    let onChoose: (TimeChoice) -> Void

    static let height: CGFloat = ChoiceSheet<EmptyView>.height

    var body: some View {
        ChoiceSheet {
            // Now leads, as the one you reach for without thinking. Create is the middle because
            // it is the most common of the three and the thumb lands there.
            ChoiceCard(mark: .now, title: "Now") { onChoose(.now) }
            ChoiceCard(mark: .newEvent, title: "Create") { onChoose(.create) }
            ChoiceCard(mark: .calendar, title: "Pick date") { onChoose(.pickDate) }
        }
    }
}
