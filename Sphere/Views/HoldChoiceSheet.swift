import SwiftUI

enum HoldChoice {
    case now
    case menu
}

/// What a hold offers: this moment, or the day's menu.
///
/// The hold went straight to the menu until 2026-10-13. It is the one gesture on the arc that
/// reports no position — a long press says when it happened and nothing about where — so it is
/// the right carrier for the two actions that do not care where the finger was. Now came here
/// from the tap's sheet for exactly that reason, and the menu it used to open directly is the
/// second card.
///
/// Two cards, so the gesture that cost nothing to aim still costs one press to answer. The
/// two-finger tap went to the first of them later the same day (Mason, 2026-10-13): it is the
/// one of the two that is a move rather than a place, so it is what a shortcut is for, and the
/// menu is what the cards are for. Now is therefore reachable two ways on purpose, the hold for
/// anyone finding it and two fingers for anyone who already has.
struct HoldChoiceSheet: View {
    let onChoose: (HoldChoice) -> Void

    static let height: CGFloat = ChoiceSheet<EmptyView>.height

    var body: some View {
        ChoiceSheet { HoldChoiceSheet.cards(onChoose: onChoose) }
    }

    /// Shared by the sheet and by `ChoicePanel`, so the two presentations cannot drift.
    @ViewBuilder
    static func cards(onChoose: @escaping (HoldChoice) -> Void) -> some View {
            // Now leads, as the one you reach for without thinking — the order it had in the
            // tap's sheet, kept so the card has not moved for anyone who learned it there.
            ChoiceCard(mark: .now, title: "Now") { onChoose(.now) }
            ChoiceCard(mark: .menu, title: "Menu") { onChoose(.menu) }
    }
}
