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
struct EventChoiceSheet: View {
    let onChoose: (EventChoice) -> Void

    static let height: CGFloat = 172

    var body: some View {
        HStack(spacing: 14) {
            button(.openEvent, title: "Open") { onChoose(.open) }
            button(.newEvent, title: "New") { onChoose(.create) }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }

    /// Drawn in the wheel's line and weight, since it is the wheel's own button
    /// that opened this. Presses dim rather than scale, for the same reason
    /// they do there.
    private func button(_ mark: Mark, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ActionMark(mark: mark, size: 34, color: Theme.ink)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Theme.mutedLighter, lineWidth: 1.5)
            }
            .contentShape(.rect)
        }
        .buttonStyle(DimOnPress())
    }
}

private struct DimOnPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.45 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
