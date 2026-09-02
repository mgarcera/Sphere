import SwiftUI

enum EventChoice {
    case open
    case create
}

/// What the centre button does when the dot is already inside an event.
///
/// Opening it was the only thing on offer, so an hour that already held
/// something could not have anything else put in it. Real days nest: a call
/// inside a block, a break inside a shift.
///
/// Two buttons and nothing else. A heading and a caption under each were tried
/// and cut: the fork has exactly two answers, both are one word, and anything
/// more made a choice that should take no thought look like a form.
/// The two cards themselves, with no opinion about how they got on screen.
struct EventChoiceCards: View {
    var height: CGFloat = 260
    let onChoose: (EventChoice) -> Void

    var body: some View {
        // New leads. Creating is the thing you could not do before, and the
        // event you are already inside is the one you can always get back to.
        HStack(spacing: 14) {
            card(.newEvent, title: "New") { onChoose(.create) }
            card(.openEvent, title: "Open") { onChoose(.open) }
        }
        .frame(height: height)
    }

    /// Drawn in the wheel's line and weight, since it is the wheel's own button
    /// that opened this. Presses dim rather than scale, for the same reason
    /// they do there.
    private func card(_ mark: Mark, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 18) {
                ActionMark(mark: mark, size: 96, color: Theme.ink, stroke: 2.0)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Theme.background)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(Theme.mutedLighter, lineWidth: 1.5)
                    }
            }
            .contentShape(.rect)
        }
        .buttonStyle(DimOnPress())
    }
}

/// A · the cards inside a sheet whose own background is cleared, so only they
/// draw. The sheet keeps its drag gesture and whatever it does to the view
/// behind it.
struct EventChoiceSheet: View {
    let onChoose: (EventChoice) -> Void

    static let height: CGFloat = 320

    var body: some View {
        EventChoiceCards(height: 260, onChoose: onChoose)
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct DimOnPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.45 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
