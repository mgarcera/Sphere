import SwiftUI

/// The one thing the wheel cannot say about itself.
///
/// Five positions are printed — `‹ MENU › ● CAL` — and every one of them also has a hold:
/// previous/next day on the chevrons, the other of the CAL/NOW pair on the bottom, a new all-day
/// event on the centre, light/dark on MENU. None of that is printed anywhere, deliberately, because
/// holds are reassignable and a label that can come to mean something else stops being readable
/// (see `WheelPosition.defaultHold`). The cost of that decision is that the whole second layer of
/// the app is invisible unless you open the menu already suspecting it exists.
///
/// So the tip teaches the LAYER, not any one action. "Hold ‹ for the previous day" would teach one
/// of five and would have to be rewritten whenever a hold is reassigned; this needs no knowledge of
/// the current mapping and stays true through any of them.
struct WheelTip: View {
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            HStack(alignment: .top, spacing: 10) {
                Text("**Tip:** You can press and hold every button on the wheel to access a secondary action. Some of them can be changed in the menu.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                // Not decoration: this is the only thing saying the card can be got rid of, and
                // the card has no timer to get rid of it.
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: 300, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.hairline, lineWidth: 1)
                    )
                    // The card floats over the sky rather than sitting in the layout, so it needs
                    // to read as nearer than what is behind it.
                    .shadow(color: .black.opacity(0.10), radius: 14, y: 4)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Dismisses the tip")
    }
}

/// Whether the tip has more to say, kept across launches.
///
/// Two facts, and the pair is what makes it retire honestly. **Retired** is set the first time any
/// hold fires anywhere on the wheel: the user has the layer, so the tip has done its job and never
/// appears again, even on launch two. **Launches** caps it at three showings for everyone else, so
/// missing it once is survivable and it can never become furniture for someone who simply never
/// holds anything.
///
/// Dismissing the card is NOT retirement. It ends this showing, and the launch it consumed is
/// already spent; a tap means "not now", and only a hold means "understood".
@MainActor
enum WheelTipState {
    static let maxLaunches = 3

    private static let shownKey = "wheelTip.launchesShown"
    private static let retiredKey = "wheelTip.retired"

    static var isRetired: Bool { UserDefaults.standard.bool(forKey: retiredKey) }

    /// Spends one of the three showings, if there is one to spend. Called once per launch, and
    /// only once the wheel is actually on screen — during the calendar priming there is no wheel
    /// to point at, and a tip over a permission prompt is two asks at once.
    static func claimLaunch() -> Bool {
        guard !isRetired else { return false }
        let shown = UserDefaults.standard.integer(forKey: shownKey)
        guard shown < maxLaunches else { retire(); return false }
        UserDefaults.standard.set(shown + 1, forKey: shownKey)
        return true
    }

    /// The user held something. Nothing left to teach.
    static func retire() { UserDefaults.standard.set(true, forKey: retiredKey) }
}
