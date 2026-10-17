import SwiftUI

enum CornerChoice {
    case menu
    case guide
}

/// What the corner button offers, and since 2026-10-14 what a long press on the arc offers too:
/// the menu, or the gestures. One sheet, two ways in, rather than two sheets — a hold and a
/// corner button that asked the same question from two files would drift in a week.
///
/// It read "the '?' in the corner" and led with Guide until 2026-10-16, when the corner became a
/// menu mark on the trailing side and Menu took the first card (Mason). The two changes are one
/// decision: a glyph that says menu should not hand you the guide first.
///
/// The corner opened the guide outright until 2026-10-13, and the menu had no visible route at
/// all — it answered only to a hold, and after the two-finger tap moved to Now that hold's
/// second card was the single way in (`isMenuOpen` had one assignment in `ContentView`). The
/// app's own argument against leaving it there was already written down: the question mark
/// existed so the guide was "repeatable without burying it in a menu where C proved it would not
/// be found" (DECISIONS.md, 2.0). A surface nobody can find is the same problem whichever
/// direction it runs in — which is the argument that 2026-10-16 spends, and the reason it is
/// quoted twice in this file.
///
/// So the corner asks, which is this app's answer whenever one gesture has two things behind it:
/// the tap asks, the hold asks, the corner asks. Mason chose this over a second mark beside the
/// first, which would have kept both routes one press deep at the cost of starting a toolbar in
/// the corner of a canvas that carries almost nothing. The other corner did gain a control on
/// 2026-10-16, the Now readout, but it is conditional and so is not standing furniture.
///
/// The hold arrived here on 2026-10-14, when Now went back to the tap. `HoldChoiceSheet` was
/// deleted in the same commit rather than left as a second copy of these two cards. The hold is
/// the one gesture on the arc that reports no position, which is why the two surfaces that care
/// least where the finger was — the explanation of the app, and everything else in it — are the
/// two it carries.
///
/// The cost, stated where it was taken: help is now one press further away, and help is what a
/// stuck reader reaches for. **Three things held it down and now two do**, which is the price of
/// 2026-10-16 and is written here rather than argued away.
///
/// Gone: the guide led, so the press that had always opened the guide still landed on the guide's
/// own card. It lands on Menu now, from a button that no longer looks like help at all. This runs
/// against the app's own 2.0 argument, that the guide had to be repeatable "without burying it in
/// a menu where C proved it would not be found" — and a menu mark opening a Menu card is nearer
/// to that than a question mark was. Mason was told so before the change and chose it.
///
/// Still holding: the corner is not the only way in, since the guide rises by itself when the
/// onboarding hands over and once more for anyone already past it, neither of which goes through
/// these cards. And the hold reaches the same pair, so help is behind two gestures rather than
/// one.
struct CornerChoiceSheet: View {
    let onChoose: (CornerChoice) -> Void

    static let height: CGFloat = ChoiceSheet<EmptyView>.height

    var body: some View {
        ChoiceSheet { CornerChoiceSheet.cards(onChoose: onChoose) }
    }

    /// Shared by the sheet and by `ChoicePanel`, so the two presentations cannot drift.
    @ViewBuilder
    static func cards(onChoose: @escaping (CornerChoice) -> Void) -> some View {
            // Menu leads as of 2026-10-16 (Mason), in the same change that made the corner
            // button a menu mark. The two go together: a menu glyph whose first card is the
            // guide would be pointing at the thing it is not.
            ChoiceCard(mark: .menu, title: "Menu") { onChoose(.menu) }
            ChoiceCard(mark: .guide, title: "Guide") { onChoose(.guide) }
    }
}
