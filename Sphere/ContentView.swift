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
                suppressedBy: washAmount / WeatherWash.stormPeak
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
                .foregroundStyle(captionColor)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    /// How much wash is present, for twilight to yield to.
    private var washAmount: Double {
        let sky = model.weather(atAbsoluteHour: model.focusHour)
        return WeatherWash.amount(precipitation: sky.precipitation, lightning: sky.lightning)
    }

    private var effectiveScheme: ColorScheme {
        appearance.colorScheme ?? systemScheme
    }

    /// The header sits in the darkest part of the wash, so its ink flips to
    /// the background colour once the sky is genuinely dark. In dark mode the
    /// ink is already light and the ground only gets darker, so it stays.
    ///
    /// This switches on the MEASURED luminance under the header, not on how
    /// much wash there is. Those are different: heavy rain scores 0.5 on amount
    /// yet composites to a light grey that dark ink reads on at 8:1, while a
    /// storm scores 0.78 and composites to near-black.
    private func onWash(_ base: Color) -> Color {
        guard effectiveScheme == .light else { return base }
        return base.mix(with: Theme.background, by: washSwitch)
    }

    /// The caption is the one that vanishes, because #8A8A8A is a light grey
    /// whose luminance passes straight THROUGH the wash's: measured against
    /// medium rain it fell to 1.8:1 and at the crossing point it is literally
    /// 1:1. Flipping earlier alone does not fix that, since both sides of the
    /// flip are weak there. So it darkens toward the ink as the ground darkens,
    /// moving away from the background rather than into it, and only flips once
    /// the ground is dark enough for light text to win outright.
    private var captionColor: Color {
        guard effectiveScheme == .light else { return Theme.muted }
        if headerLuminance < Self.flipLuminance {
            // Not pure white: it stays subordinate to the title.
            return Theme.background.mix(with: Theme.ink, by: 0.12)
        }
        let darkening = min(max((1 - headerLuminance) / 0.6, 0), 1)
        return Theme.muted.mix(with: Theme.ink, by: darkening)
    }

    private var headerLuminance: Double {
        let sky = model.weather(atAbsoluteHour: model.focusHour)
        return WeatherWash.topLuminance(precipitation: sky.precipitation, lightning: sky.lightning)
    }

    /// Biased earlier than the measured optimum of 0.20, deliberately: the
    /// caption is the one that disappears first and it should be white by then.
    private static let flipLuminance: Double = 0.26

    private var washSwitch: Double {
        headerLuminance < Self.flipLuminance ? 1 : 0
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
