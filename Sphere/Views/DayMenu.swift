import SwiftUI

/// What MENU opens. Three things that have nowhere else to live: the way back
/// to now, the way to another date, and the two lists the arc cannot hold —
/// all-day events, which have no hour, and which calendars count.
struct DayMenu: View {
    let model: DayModel
    let calendar: CalendarService
    let onDismiss: () -> Void

    @State private var pickedDate: Date = .now

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                nowRow
                divider

                HStack {
                    Text("Date")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    DatePicker("", selection: $pickedDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Theme.ink)
                }
                .padding(.vertical, 13)

                if !model.allDayEvents.isEmpty {
                    divider
                    section("All day") {
                        ForEach(model.allDayEvents) { event in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(event.color)
                                    .frame(width: 8, height: 8)
                                Text(event.title)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                            }
                            .padding(.vertical, 7)
                        }
                    }
                }

                if !calendar.sources.isEmpty {
                    divider
                    section("Calendars") {
                        ForEach(calendar.sources) { source in
                            Toggle(isOn: Binding(
                                get: { calendar.isVisible(source) },
                                set: { calendar.setVisible($0, for: source) }
                            )) {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(source.color)
                                        .frame(width: 8, height: 8)
                                    Text(source.title)
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.ink)
                                }
                            }
                            .tint(Theme.ink)
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Theme.background)
        .onAppear { pickedDate = model.focusDate }
        .onChange(of: pickedDate) { _, newValue in
            model.focus(onDayOf: newValue)
        }
    }

    private var nowRow: some View {
        Button {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                model.returnToNow()
            }
            onDismiss()
        } label: {
            HStack {
                Text("Now")
                    .font(.display(19))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(ArcContent.clock(model.nowHour.truncatingRemainder(dividingBy: 24)))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()
            }
            .contentShape(.rect)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.mutedLight)
                .padding(.top, 16)
                .padding(.bottom, 6)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }
}
