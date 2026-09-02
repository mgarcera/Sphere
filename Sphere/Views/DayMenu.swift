import SwiftUI

/// What MENU opens. Everything that has nowhere else to live: another date,
/// all-day events (which have no hour, so the arc cannot hold them), which
/// calendars count, and the sun's times now that the arc no longer labels
/// them. The times are readings, not controls.
struct DayMenu: View {
    let model: DayModel
    let calendar: CalendarService
    let location: LocationService
    @Binding var appearance: Appearance
    let onDismiss: () -> Void

    @State private var pickedDate: Date = .now
    @State private var placeQuery = ""
    @FocusState private var placeFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                dayBlock

                divider
                section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Text(option.title).tag(option)
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
                            .tint(Theme.controlAccent)
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

    // MARK: - Layouts

    /// The day itself as one block, with the sun as a strip under it.
    private var dayBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(location.placeName)
                    .font(.display(24))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if location.isUsingFallback {
                    Text("default")
                        .font(.caption2)
                        .foregroundStyle(Theme.mutedLight)
                }
                Spacer(minLength: 8)
                DatePicker("", selection: $pickedDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(Theme.controlAccent)
                    .fixedSize()
            }

            HStack {
                placeSearch
                Spacer(minLength: 8)
                placeAction
            }

            Rectangle().fill(Theme.hairline).frame(height: 1).padding(.top, 4)
            sunRow
            moonRow
        }
        .padding(.vertical, 12)
    }

    // MARK: - Shared pieces

    private var placeName: some View {
        HStack {
            Text(location.placeName)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            if location.isUsingFallback {
                Text("default")
                    .font(.caption2)
                    .foregroundStyle(Theme.mutedLight)
            }
            Spacer()
            placeAction
        }
    }

    @ViewBuilder
    private var placeAction: some View {
        if location.manual != nil {
            Button("Use mine") { location.clearManual() }
                .font(.footnote)
                .foregroundStyle(Theme.taskActive)
        } else if location.access != .granted {
            Button("Allow") { location.request() }
                .font(.footnote)
                .foregroundStyle(Theme.taskActive)
        }
    }

    private var placeSearch: some View {
        HStack(spacing: 8) {
            TextField("Search a city", text: $placeQuery)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .focused($placeFocused)
                .submitLabel(.search)
                .onSubmit { submitPlace() }
            if location.isSearching {
                ProgressView().controlSize(.small)
            }
        }
    }

    /// Three moments across the width, each one a mark with its label and time
    /// left-aligned beside it rather than centred under it.
    private var sunRow: some View {
        let day = model.focusSolarDay
        return HStack(alignment: .center, spacing: 8) {
            sunCell(.rise, "Sunrise", day.sunrise)
            sunCell(.noon, "Midday", day.solarNoon)
            sunCell(.set, "Sunset", day.sunset)
        }
    }

    private func sunCell(_ moment: SunMark.Moment, _ title: String, _ hour: Double?) -> some View {
        HStack(spacing: 7) {
            SunMark(moment: moment)
                .stroke(Theme.muted, style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
                .frame(width: 17, height: 17)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Theme.mutedLight)
                Text(hour.map(ArcContent.clock) ?? "—")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var moonRow: some View {
        HStack {
            Text(model.focusMoonPhase.name)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            Spacer()
            Text("\(Int((model.focusMoonPhase.illuminated * 100).rounded()))% lit")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .monospacedDigit()
        }
    }

    private func submitPlace() {
        let query = placeQuery
        Task {
            if await location.search(query) {
                placeQuery = ""
                placeFocused = false
            }
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
