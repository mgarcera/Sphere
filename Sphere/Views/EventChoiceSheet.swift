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
/// Two entry points, and they ask about different events. The header title button asks about
/// the event under the DOT and creates at the focus. A tap on the arc asks about the event
/// under the FINGER and creates at the time under the finger. The caller carries both answers
/// in; this sheet only asks which.
///
/// Two buttons and nothing else. A heading and a caption under each were tried
/// and cut: anything that explains a one-word choice makes it look like a form.
///
/// Three cards since 2026-10-10, and the same three the other sheet offers but for Open in place
/// of Now (Mason). Aiming at an event and aiming at empty time are the same act with a different
/// thing under the finger, so the sheets differ by one card rather than by shape.
struct EventChoiceSheet: View {
    let onChoose: (EventChoice) -> Void

    static let height: CGFloat = ChoiceSheet<EmptyView>.height

    var body: some View {
        ChoiceSheet {
            // Open leads: it is the one that is about the thing you aimed at. The other two are
            // the same two the time sheet offers, in the same order, so the pair reads as one
            // set with its first card swapped.
            ChoiceCard(mark: .openEvent, title: "Open") { onChoose(.open) }
            ChoiceCard(mark: .newEvent, title: "New event") { onChoose(.create) }
            ChoiceCard(mark: .calendar, title: "Pick date") { onChoose(.pickDate) }
        }
    }
}
