import SwiftUI

/// The week the wheel is in, as dates, under the title.
///
/// It replaces a written date line. A date on its own says which day it is; a
/// week says that AND where the day sits in it, which is the thing the written
/// line could only spell out in a word.
///
/// Sunday to Saturday, so the shape of a week is the shape everyone already
/// carries, and it slides a week at a time rather than scrolling.
struct WeekStrip: View {
    /// Seven days, Sunday first.
    let days: [Date]
    /// The wheel's day.
    let selected: Int
    /// Today, when today is in this week. A second, quieter mark: the strip
    /// follows the wheel, and the wheel wanders.
    let today: Int?
    let timeZone: TimeZone

    let ink: Color
    let ground: Color
    let muted: Color
    let hairline: Color

    let onPick: (Date) -> Void
    let onHold: () -> Void

    private static let dot: CGFloat = 27

    /// Bouncy on purpose: the selection has a short distance to travel and the
    /// overshoot is most of what reads as a pop.
    private static let pop = Animation.spring(response: 0.26, dampingFraction: 0.55)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element) { index, day in
                column(index: index, day: day)
                    .frame(maxWidth: .infinity)
                    // The stagger arrives WITH the week: one column a little
                    // after the last. On the way in only — a delay reads as
                    // sequence when several things arrive and as lag when one
                    // thing leaves.
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
                    .transaction { $0.animation = $0.animation?.delay(Double(index) * 0.035) }
            }
        }
    }

    private func column(index: Int, day: Date) -> some View {
        let isSelected = index == selected

        return VStack(spacing: 4) {
            Text(Self.letter(day, in: timeZone))
                .font(.system(size: 9, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(muted.opacity(0.75))
                .contentTransition(.identity)

            ZStack {
                Circle()
                    .strokeBorder(hairline, lineWidth: 1)
                Circle()
                    .fill(ink)
                    .opacity(isSelected ? 1 : 0)

                Text(Self.number(day, in: timeZone))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    // Without this the numbers crossfade into each other when
                    // the week slides, which is the transaction's doing rather
                    // than anything asked for.
                    .contentTransition(.identity)
                    .foregroundStyle(isSelected ? ground : muted)
            }
            .frame(width: Self.dot, height: Self.dot)
            .scaleEffect(isSelected ? 1 : 0.92)

            // Today, when the wheel has wandered off it.
            Circle()
                .fill(muted)
                .frame(width: 3, height: 3)
                .opacity(index == today && !isSelected ? 1 : 0)
        }
        .animation(Self.pop, value: selected)
        .contentShape(.rect)
        .onTapGesture { onPick(day) }
        .onLongPressGesture(minimumDuration: 0.35) { onHold() }
    }

    private static func letter(_ date: Date, in zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }

    private static func number(_ date: Date, in zone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return String(calendar.component(.day, from: date))
    }
}
