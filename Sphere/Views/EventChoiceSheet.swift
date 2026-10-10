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
/// The two cards themselves, with no opinion about how they got on screen. Kept beside the
/// sheet because the floating variant it was pulled out for may come back; `ChoiceCard` and
/// `ChoiceSheet` in ChoiceCard.swift hold the treatment both sheets draw with.
struct EventChoiceCards: View {
    let onChoose: (EventChoice) -> Void

    var body: some View {
        // New leads. Creating is the thing you could not do before, and the event you are
        // already inside is the one you can always get back to.
        HStack(spacing: 14) {
            ChoiceCard(mark: .newEvent, title: "New event") { onChoose(.create) }
            ChoiceCard(mark: .openEvent, title: "Open") { onChoose(.open) }
        }
        .frame(height: 150)
    }
}

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
