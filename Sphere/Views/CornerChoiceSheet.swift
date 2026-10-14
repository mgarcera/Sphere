import SwiftUI

enum CornerChoice {
    case guide
    case menu
}

/// What the "?" in the corner offers: the gestures, or the menu.
///
/// The corner opened the guide outright until 2026-10-13, and the menu had no visible route at
/// all — it answered only to a hold, and after the two-finger tap moved to Now that hold's
/// second card was the single way in (`isMenuOpen` had one assignment in `ContentView`). The
/// app's own argument against leaving it there is already written down: the question mark exists
/// so the guide is "repeatable without burying it in a menu where C proved it would not be
/// found" (DECISIONS.md, 2.0). A surface nobody can find is the same problem whichever direction
/// it runs in.
///
/// So the corner asks, which is this app's answer whenever one gesture has two things behind it:
/// the tap asks, the hold asks, and now the corner does. Mason chose this over a second mark
/// beside the question mark, which would have kept both routes one press deep at the cost of
/// starting a toolbar in the corner of a canvas that carries almost nothing.
///
/// The cost, stated where it was taken: help is now one press further away, and help is what a
/// stuck reader reaches for. Two things hold it down. The guide leads, so the press that always
/// opened the guide still lands on the guide's own card. And the corner is not the only way in —
/// the guide still rises by itself when the onboarding hands over, and once more for anyone who
/// was already past it, neither of which goes through these cards.
struct CornerChoiceSheet: View {
    let onChoose: (CornerChoice) -> Void

    static let height: CGFloat = ChoiceSheet<EmptyView>.height

    var body: some View {
        ChoiceSheet { CornerChoiceSheet.cards(onChoose: onChoose) }
    }

    /// Shared by the sheet and by `ChoicePanel`, so the two presentations cannot drift.
    @ViewBuilder
    static func cards(onChoose: @escaping (CornerChoice) -> Void) -> some View {
            ChoiceCard(mark: .guide, title: "Guide") { onChoose(.guide) }
            ChoiceCard(mark: .menu, title: "Menu") { onChoose(.menu) }
    }
}
