import SwiftUI

enum EventChoice {
    case open
    case create
}

/// What the centre button does when the dot is already inside an event.
///
/// Opening it was the only thing on offer, so an hour that already had
/// something in it could not have anything else put in it. Real days nest: a
/// call inside a block, a break inside a shift. Both are printed rather than
/// one being a hidden gesture, and the fork only appears where there is one —
/// in empty time the centre button still creates without asking.
struct EventChoiceSheet: View {
    let eventTitle: String
    let hour: String
    let onChoose: (EventChoice) -> Void

    static let height: CGFloat = 56 + 86

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("This hour")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.mutedLight)
                .padding(.top, 18)
                .padding(.bottom, 12)

            HStack(alignment: .top, spacing: 18) {
                column(.openEvent, title: "Open", detail: eventTitle) { onChoose(.open) }

                Rectangle()
                    .fill(Theme.hairline)
                    .frame(width: 1)

                column(.newEvent, title: "New", detail: hour) { onChoose(.create) }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
    }

    /// The detail is what distinguishes the two: the event you are in against
    /// the hour you are on.
    private func column(_ mark: Mark, title: String, detail: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ActionMark(mark: mark, size: 18, color: Theme.ink)
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                }
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedLight)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
