import SwiftUI

enum EventChoice {
    case open
    case create
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
/// and cut: the fork has exactly two answers, both are one word, and anything
/// more made a choice that should take no thought look like a form.
struct EventChoiceSheet: View {
    let onChoose: (EventChoice) -> Void

    static let height: CGFloat = ChoiceSheet<EmptyView>.height

    var body: some View {
        ChoiceSheet {
            ChoiceCard(mark: .newEvent, title: "New event") { onChoose(.create) }
            ChoiceCard(mark: .openEvent, title: "Open") { onChoose(.open) }
        }
    }
}
