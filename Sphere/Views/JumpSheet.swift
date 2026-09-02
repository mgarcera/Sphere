import SwiftUI

/// The two places DATE can send you.
enum JumpChoice {
    case now
    case calendar
}

/// Where DATE goes, asked rather than assumed.
///
/// Returning to now used to be a tap on the arc: the one surface big enough to
/// carry a gesture nothing can label. Unlabelled is the problem — nothing on
/// screen said the day was tappable. Both destinations are printed here
/// instead, and DATE costs one tap either way.
///
/// Fixed height and one detent, like the all-day sheet. It is a fork, not a
/// place to be.
struct JumpSheet: View {
    let now: Date
    let focused: Date
    let onChoose: (JumpChoice) -> Void

    static let height: CGFloat = 56 + 2 * 52

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Jump to")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.mutedLight)
                .padding(.top, 18)
                .padding(.bottom, 8)

            row("Now", detail: Self.time.string(from: now)) { onChoose(.now) }
            Rectangle().fill(Theme.hairline).frame(height: 1)
            row("Calendar", detail: Self.day.string(from: focused)) { onChoose(.calendar) }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
    }

    /// The detail is what you are choosing between: the clock time you would
    /// land on, against the day you are already looking at.
    private func row(_ title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedLight)
            }
            .contentShape(.rect)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }

    private static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}
