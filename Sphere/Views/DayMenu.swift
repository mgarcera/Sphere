import SwiftUI

/// What MENU opens. Everything that has nowhere else to live: another date,
/// all-day events (which have no hour, so the arc cannot hold them), which
/// calendars count, and the sun's times now that the arc no longer labels
/// them. The times are readings, not controls.
struct DayMenu: View {
    let model: DayModel
    let calendar: CalendarService
    let location: LocationService
    let weather: WeatherService
    @Binding var appearance: Appearance
    @AppStorage(WheelMapping.bottomKey) private var bottomPrimary: WheelAction = .now
    let onDismiss: () -> Void

    @State private var placeQuery = ""
    @State private var search = PlaceSearch()
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

                divider
                section("Wheel") {
                    WheelSettings(bottomPrimary: $bottomPrimary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Theme.background)
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
                nowCorner
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    placeSearch
                    Spacer(minLength: 8)
                    placeAction
                }
                suggestions
            }

            Rectangle().fill(Theme.hairline).frame(height: 1).padding(.top, 4)
            MiniArc(day: model.todaySolarDay, nowHour: model.todayHourOfDay)
                .padding(.top, 2)
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
            TextField("City, postcode or address", text: $placeQuery)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .focused($placeFocused)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { submitPlace() }
                .onChange(of: placeQuery) { _, query in search.update(query: query) }
            if location.isSearching {
                ProgressView().controlSize(.small)
            }
        }
    }

    /// Results as you type, so the field answers before you commit to it.
    @ViewBuilder
    private var suggestions: some View {
        if !search.suggestions.isEmpty {
            VStack(spacing: 0) {
                ForEach(search.suggestions) { suggestion in
                    Button { choose(suggestion) } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(suggestion.title)
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.mutedLight)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    if suggestion.id != search.suggestions.last?.id {
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private func choose(_ suggestion: PlaceSearch.Suggestion) {
        Task {
            guard let resolved = await search.resolve(suggestion) else { return }
            location.adopt(coordinate: resolved.coordinate, name: resolved.name)
            placeQuery = ""
            placeFocused = false
            search.clear()
        }
    }

    /// The real now, in the corner: tonight's moon and what it is doing
    /// outside, both independent of where the wheel is.
    private var nowCorner: some View {
        let sky = weather.hour(at: .now)
        return HStack(spacing: 10) {
            HStack(spacing: 5) {
                MoonShape(illuminated: model.nowMoonPhase.illuminated,
                          isWaxing: model.nowMoonPhase.isWaxing)
                    .fill(Theme.muted)
                    .overlay(Circle().strokeBorder(Theme.muted.opacity(0.35), lineWidth: 1))
                    .frame(width: 13, height: 13)
                Text("\(Int((model.nowMoonPhase.illuminated * 100).rounded()))%")
                    .font(.caption2)
                    .foregroundStyle(Theme.mutedLight)
                    .monospacedDigit()
            }

            if let sky {
                HStack(spacing: 5) {
                    SkyGlyph(condition: sky.condition)
                        .stroke(Theme.muted, style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
                        .frame(width: 15, height: 15)
                    if let celsius = sky.celsius {
                        Text(Measurement(value: celsius, unit: UnitTemperature.celsius)
                            .formatted(.measurement(width: .narrow, usage: .weather)))
                            .font(.caption2)
                            .foregroundStyle(Theme.mutedLight)
                            .monospacedDigit()
                    }
                }
            }
        }
        .fixedSize()
    }

    private func submitPlace() {
        let query = placeQuery
        Task {
            if await location.search(query) {
                placeQuery = ""
                placeFocused = false
                search.clear()
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
