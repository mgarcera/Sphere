import SwiftUI

enum HoldChoice {
    case now
    case pickDate
}

/// What a hold on the arc offers: the current time, or another day.
///
/// The hold used to open the menu directly and the two-finger tap used to return to now. They
/// swapped on 2026-10-10 (Mason): holding asks WHERE in time to go, which is the question the
/// arc is about, and the menu — haptics, sounds, alerts, which calendars show — moved to the
/// two-finger tap because it is a destination you visit, not a move you make.
///
/// Built on the same cards as the New/Open sheet. Two of them, both one word.
struct HoldChoiceSheet: View {
    let onChoose: (HoldChoice) -> Void

    static let height: CGFloat = ChoiceSheet<EmptyView>.height

    var body: some View {
        ChoiceSheet {
            // Now leads. It is the one you reach for without thinking, and picking a date is
            // the deliberate one.
            ChoiceCard(mark: .now, title: "Now") { onChoose(.now) }
            ChoiceCard(mark: .calendar, title: "Pick date") { onChoose(.pickDate) }
        }
    }
}
