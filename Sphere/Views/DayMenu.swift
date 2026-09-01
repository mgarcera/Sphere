import SwiftUI

/// What MENU opens. Everything that has nowhere else to live: another date,
/// all-day events (which have no hour, so the arc cannot hold them), which
/// calendars count, and the sun's times now that the arc no longer labels
/// them. The times are readings, not controls.
struct DayMenu: View {
    let model: DayModel
    let calendar: CalendarService
    @Binding var skyStyle: SkyStyle
    let onDismiss: () -> Void

    @State private var pickedDate: Date = .now

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
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

                divider
                section("Sun") {
                    let day = model.focusSolarDay
                    reading("Sunrise", day.sunrise)
                    reading("Midday", day.solarNoon)
                    reading("Sunset", day.sunset)
                    HStack {
                        Text(model.focusMoonPhase.name)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(Int((model.focusMoonPhase.illuminated * 100).rounded()))% lit")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 6)
                }

                divider
                section("Sky style") {
                    Picker("Sky style", selection: $skyStyle) {
                        ForEach(SkyStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
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

    /// Information only. NOW on the wheel is what moves you.
    private func reading(_ title: String, _ hour: Double?) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(hour.map(ArcContent.clock) ?? "—")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
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
