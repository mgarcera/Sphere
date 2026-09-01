import EventKit
import SwiftUI

struct ContentView: View {
    @State private var model = DayModel()
    @State private var calendar = CalendarService()
    @State private var location = LocationService()
    @State private var weather = WeatherService()
    @State private var editorTarget: EventTarget?
    @Environment(\.colorScheme) private var systemScheme
    @State private var isMenuOpen = false
    @AppStorage("appearance") private var appearance: Appearance = .system
    /// Temporary design test, not a permanent setting.
    @AppStorage("wheelStyle") private var wheelStyle: WheelStyle = .chrome

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            let sky = model.weather(atAbsoluteHour: model.focusHour)

            TwilightBackground(
                elevationDegrees: model.elevationDegrees(atAbsoluteHour: model.focusHour),
                isMorning: model.focusHour - Double(model.dayIndex) * 24 < model.focusSolarDay.solarNoon,
                suppressedBy: washDarkness / WeatherWash.stormPeak
            )

            // Weather sits over the time of day, being nearer.
            WeatherWash(precipitation: sky.precipitation, lightning: sky.lightning)

            if calendar.access == .undetermined {
                CalendarPriming {
                    location.request()
                    Task {
                        await calendar.requestAccess()
                        reload()
                    }
                }
                .transition(.opacity)
            } else {
                day
            }
        }
        .animation(.easeInOut(duration: 0.25), value: calendar.access)
        .preferredColorScheme(appearance.colorScheme)
        .sheet(item: $editorTarget) { target in
            EventEditorSheet(store: calendar.store, target: target) {
                editorTarget = nil
                Task { @MainActor in reload() }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isMenuOpen) {
            DayMenu(model: model, calendar: calendar, location: location, appearance: $appearance, wheelStyle: $wheelStyle) { isMenuOpen = false }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            // Ask independently of priming. Anyone who granted calendar before
            // location existed never sees that screen again, and was silently
            // getting Chicago's sky.
            if location.access == .undetermined { location.request() }
            await weather.load(coordinate: location.coordinate)
            model.applySky(from: weather)
            reload()
            model.tick()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                model.tick()
            }
        }
        // Someone editing in Calendar.app would otherwise leave the arc stale.
        .task {
            for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
                reload()
            }
        }
        .onChange(of: model.dayIndex) { _, _ in
            reload()
            model.applySky(from: weather)
        }
        // A fix moves the whole arc, since the curve is the sun's elevation
        // where you actually are.
        .onChange(of: location.coordinate) { _, coordinate in
            model.relocate(to: coordinate)
            Task {
                await weather.load(coordinate: coordinate)
                model.applySky(from: weather)
            }
        }
        .onChange(of: calendar.hiddenSourceIDs) { _, _ in reload() }
    }

    private var day: some View {
        VStack(spacing: 0) {
            header

            ArcWindow(model: model)
                .padding(.top, 8)

            Spacer(minLength: 16)

            ClickWheel(
                onRotate: { model.scrub(byRotations: $0) },
                onMenu: { isMenuOpen = true },
                onNow: { springTo { model.returnToNow() } },
                onCentre: openEditor,
                onPrevious: { springTo { model.jumpToPreviousEvent() } },
                onNext: { springTo { model.jumpToNextEvent() } },
                style: wheelStyle
            )
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .padding(.vertical, 24)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Button {
                openEditor()
            } label: {
                // Inside an event, the title is that event. Outside one, the
                // planetary hour's call to action takes over; that lands with
                // the planet cards, so the clock stands in until then.
                Text(model.activeEvent?.title ?? ArcContent.clock(hourOfDay))
                    .font(.display())
                    .foregroundStyle(onWash(Theme.ink))
                    .shadow(color: washHalo.opacity(washDarkness > 0.04 ? 0.95 : 0), radius: 5)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.opacity)
            }
            .buttonStyle(.plain)
            .disabled(model.activeEvent == nil)
            .animation(.easeInOut(duration: 0.18), value: model.activeEvent?.id)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(onWash(Theme.muted))
                .shadow(color: washHalo.opacity(washDarkness > 0.04 ? 0.95 : 0), radius: 4)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    /// How dark the top of the screen has been made by weather.
    private var washDarkness: Double {
        let sky = model.weather(atAbsoluteHour: model.focusHour)
        return WeatherWash.darkness(precipitation: sky.precipitation, lightning: sky.lightning)
    }

    private var effectiveScheme: ColorScheme {
        appearance.colorScheme ?? systemScheme
    }

    /// The header sits in the darkest part of the weather wash, so its ink
    /// flips to the background colour once the sky closes in. In dark mode the
    /// ink is already light and the ground only gets darker, so it stays.
    ///
    /// This is a SWITCH with a short crossfade, not a blend. Interpolating
    /// linearly parks the text mid-grey exactly where the background is also
    /// mid-grey: measured against the rain wash it took contrast from 8:1 down
    /// to 2:1, worse than doing nothing. Rain is light enough for dark ink and
    /// a storm is dark enough for light ink; the ramp only has to get between
    /// the two quickly.
    private func onWash(_ base: Color) -> Color {
        guard effectiveScheme == .light else { return base }
        return base.mix(with: Theme.background, by: washSwitch)
    }

    /// 0 keeps the ink dark, 1 takes it to the background colour.
    private var washSwitch: Double {
        Self.smoothstep(0.44, 0.54, washDarkness)
    }

    /// A halo in whichever colour the text is NOT. Even with a narrow switch
    /// there is a band where the background and the text are both mid-grey and
    /// contrast measures near 1:1; a soft glow behind the glyphs covers it at
    /// any luminance, which no choice of text colour can.
    private var washHalo: Color {
        Theme.background.mix(with: Theme.ink, by: washSwitch)
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private var hourOfDay: Double {
        model.focusHour - Double(model.dayIndex) * 24
    }

    /// Carries the day change, since the arc itself deliberately doesn't.
    private var subtitle: String {
        if let active = model.activeEvent {
            return "\(ArcContent.clock(active.startHour - Double(model.dayIndex) * 24)) · \(Self.dayLine(model.focusDate))"
        }
        return Self.dayLine(model.focusDate)
    }

    // MARK: - Actions

    private func reload() {
        let range = model.loadedRange
        calendar.refreshSources()
        calendar.load(from: range.start, to: range.end, anchor: model.anchor)
        model.events = calendar.events
    }

    /// On an event, the centre button edits that event. Anywhere else it
    /// starts a new one at the hour the wheel is on.
    private func openEditor() {
        if let active = model.activeEvent,
           let event = calendar.occurrence(for: active.id) {
            editorTarget = .existing(event)
        } else {
            editorTarget = .new(model.focusDate)
        }
    }

    private func springTo(_ change: () -> Void) {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86), change)
    }

    private static func dayLine(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
