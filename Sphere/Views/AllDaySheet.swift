import EventKit
import SwiftUI

/// All-day events, which have no hour and so cannot sit on the arc.
///
/// A fixed-height sheet with a single detent: it cannot be dragged open, and it
/// is not a place to browse. It shows what is true of the whole day and lets
/// each one be opened in the same editor a timed event uses.
struct AllDaySheet: View {
    let events: [CalendarEvent]
    let onOpen: (CalendarEvent) -> Void

    /// Always counted, even at one.
    private var title: String {
        "\(events.count) all day event\(events.count == 1 ? "" : "s")"
    }

    /// Enough for four rows before it scrolls, which covers a normal day of
    /// birthdays and holidays without becoming a list view.
    static func height(for count: Int) -> CGFloat {
        56 + CGFloat(min(max(count, 1), 4)) * 46
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.mutedLight)
                .padding(.top, 18)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(events) { event in
                        Button {
                            onOpen(event)
                        } label: {
                            HStack(spacing: 11) {
                                Circle()
                                    .fill(event.color)
                                    .frame(width: 9, height: 9)
                                Text(event.title)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .contentShape(.rect)
                            .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)

                        if event.id != events.last?.id {
                            Rectangle().fill(Theme.hairline).frame(height: 1)
                        }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
    }
}
