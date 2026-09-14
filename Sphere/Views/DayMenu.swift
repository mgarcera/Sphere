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
    @AppStorage(Sounds.key) private var soundsEnabled = false
    let onDismiss: () -> Void

    @State private var isFeedbackOpen = false

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

                    // Under the appearance picker rather than beside Haptics,
                    // where it used to be. Both are how Sphere presents itself
                    // rather than what it does, and a bell marks presses that
                    // are not all on the wheel.
                    Toggle(isOn: $soundsEnabled) {
                        Text("Sounds")
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                    }
                    .tint(Theme.controlAccent)
                    .padding(.vertical, 3)
                    .onChange(of: soundsEnabled) { _, on in
                        // Decode on the way in, so the first bell after
                        // switching it on is not the one that lands late.
                        if on { Sounds.warm() }
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
                            .tint(Theme.controlAccent)
                            .padding(.vertical, 3)
                        }
                    }
                } else if calendar.access == .denied {
                    divider
                    section("Calendars") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calendar access is off, so the line has no events on it.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                            Link("Open Settings", destination: SphereLinks.settings)
                                .font(.footnote)
                                .foregroundStyle(Theme.taskActive)
                        }
                    }
                }

                divider
                section("Wheel") {
                    WheelSettings(bottomPrimary: $bottomPrimary)
                }

                divider
                section("Feedback") {
                    Button {
                        isFeedbackOpen = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("Open feedback form")
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.mutedLight)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                }

                // Rows rather than links tucked in the Feedback header: these
                // are the two addresses App Store Connect points at, so they
                // are destinations in their own right. One heading over both,
                // because six headings on a single-screen menu is a lot and
                // these two carried one row each.
                divider
                section("About") {
                    linkRow("View privacy policy", to: SphereLinks.privacyPolicy)
                    linkRow("Questions and contact", to: SphereLinks.support)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Theme.background)
        .sheet(isPresented: $isFeedbackOpen) { FeedbackSheet() }
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

            // The moon and the temperature belong to the day the arc is
            // drawing, so they sit with it rather than up beside the place.
            HStack(alignment: .center) {
                Text("Today")
                    .font(.display(12))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.ink)

                Spacer(minLength: 8)
                nowCorner
            }
            .padding(.top, 2)

            MiniArc(day: model.todaySolarDay, nowHour: model.todayHourOfDay, spans: arcSpans)
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
            Button("Use location") { location.clearManual() }
                .font(.footnote)
                .foregroundStyle(Theme.taskActive)
        } else if location.access == .denied {
            // request() is a no-op once denied — iOS will not ask twice — so the
            // button has to go somewhere that can still change the answer.
            Link("Open Settings", destination: SphereLinks.settings)
                .font(.footnote)
                .foregroundStyle(Theme.taskActive)
        } else if location.access != .granted {
            Button("Use my location") { location.request() }
                .font(.footnote)
                .foregroundStyle(Theme.taskActive)
        }
    }

    private var placeSearch: some View {
        HStack(spacing: 8) {
            TextField("City, zip or address", text: $placeQuery)
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
            location.adopt(coordinate: resolved.coordinate, name: resolved.name,
                           timeZone: resolved.timeZone)
            placeQuery = ""
            placeFocused = false
            search.clear()
        }
    }

    /// The real now, in the corner: tonight's moon and what it is doing
    /// outside, both independent of where the wheel is.
    /// Today's timed events, from the store rather than from the wheel's
    /// loaded window — the arc above is today's whatever the wheel is doing,
    /// and a wheel three days out had left it empty.
    ///
    /// An event either side of midnight is clipped to the day rather than
    /// dropped, and a very short one is given enough length to read as a
    /// capsule.
    private var arcSpans: [MiniArc.Span] {
        let midnight = model.date(forDayIndex: model.todayIndex)
        let events = calendar.timedOccurrences(from: midnight,
                                               to: midnight.addingTimeInterval(86_400))
        return events.compactMap { event in
            let start = event.start.timeIntervalSince(midnight) / 3600
            let end = event.end.timeIntervalSince(midnight) / 3600
            guard end > 0, start < 24 else { return nil }
            let low = max(0, start)
            return MiniArc.Span(
                hours: low...min(24, max(end, low + 0.35)),
                color: event.color?.swiftUI ?? Theme.taskInactive,
                isCurrent: event.start <= model.realNow && model.realNow < event.end
            )
        }
    }

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
                // The same three things the header carries, in the same order:
                // the mark, the word, the temperature.
                HStack(spacing: 5) {
                    SkyGlyph(condition: sky.condition)
                        .stroke(Theme.muted, style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
                        .frame(width: 15, height: 15)
                    Text(sky.condition.title)
                        .font(.caption2)
                        .foregroundStyle(Theme.mutedLight)
                    if let celsius = sky.celsius {
                        Text(ContentView.degrees(celsius))
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

    /// Reads as the feedback button does, because it does the same kind of
    /// thing: a row that leaves the sheet.
    private func linkRow(_ title: String, to url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.mutedLight)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        section(title, trailing: { EmptyView() }, content: content)
    }

    /// A section whose header carries something on its right — links, a reading,
    /// anything belonging to the section rather than to a row inside it.
    private func section<Trailing: View, Content: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    // The app's own display face, the one the clock is set in,
                    // in the primary ink. Held back in grey they read as
                    // captions on the rows below rather than as the thing that
                    // divides the sheet.
                    .font(.display(12))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                trailing()
            }
            .padding(.top, 16)
            .padding(.bottom, 6)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }
}
