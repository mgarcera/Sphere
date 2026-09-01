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
    @State private var titleScale: CGFloat = 1
    @State private var titleFade: Double = 1
    @State private var captionScale: CGFloat = 1
    @State private var captionFade: Double = 1
    @AppStorage("appearance") private var appearance: Appearance = .system
    /// Temporary: three jump treatments under comparison.
    @AppStorage("jumpStyle") private var jumpStyle: JumpStyle = .speedLimited
    @State private var suppressedEventID: CalendarEvent.ID?
    @State private var arcFade: Double = 1

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            let sky = model.weather(atAbsoluteHour: model.focusHour)

            TwilightBackground(
                elevationDegrees: model.elevationDegrees(atAbsoluteHour: model.focusHour),
                isMorning: isMorning,
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
            DayMenu(model: model, calendar: calendar, location: location, appearance: $appearance, jumpStyle: $jumpStyle) { isMenuOpen = false }
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

            ArcWindow(model: model, suppressedEventID: suppressedEventID)
                .opacity(arcFade)
                .padding(.top, 8)

            Spacer(minLength: 16)

            ClickWheel(
                onRotate: { model.scrub(byRotations: $0) },
                onMenu: { isMenuOpen = true },
                onNow: { springTo { model.returnToNow() } },
                onCentre: openEditor,
                onPrevious: { jump(to: model.previousEvent) },
                onNext: { jump(to: model.nextEvent) }
            )
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .padding(.vertical, 24)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                openEditor()
            } label: {
                // Inside an event, the title is that event. Outside one, the
                // planetary hour's call to action takes over; that lands with
                // the planet cards, so the clock stands in until then.
                Text(model.activeEvent?.title ?? ArcContent.clock(hourOfDay))
                    .font(.display())
                    .foregroundStyle(titleColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    // Anchored left, not centre: the pair share a left edge and
                    // scaling about the middle would slide them off it.
                    .scaleEffect(titleScale, anchor: .leading)
                    .opacity(titleFade)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(model.activeEvent == nil)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(captionColor)
                .monospacedDigit()
                .scaleEffect(captionScale, anchor: .leading)
                .opacity(captionFade)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .onChange(of: titleKey) { _, _ in popTitle() }
        .onChange(of: captionKey) { _, _ in popCaption() }
    }

    /// What counts as each line CHANGING.
    ///
    /// Neither is the rendered string. With no event under the dot the title is
    /// a live clock, so keying off its text would fire the pop every second and
    /// on every frame of a scrub.
    ///
    /// The title moves only when the EVENT identity does. The caption also
    /// moves on the date, so crossing midnight pops the caption alone and the
    /// clock above it carries straight through.
    private var titleKey: String { model.activeEvent?.id ?? "-" }

    private var captionKey: String {
        "\(titleKey)|\(Self.dayLine(model.focusDate))"
    }

    /// Drop to 94% and fade out, then spring back. Scale and opacity are leaf
    /// modifiers driven from a discrete change, so the body runs once per pop
    /// and Core Animation does the rest.
    private static let popSpring = Animation.spring(response: 0.26, dampingFraction: 0.62)
    private static let popFade = Animation.easeOut(duration: 0.20)

    private func popTitle() {
        titleScale = 0.94
        titleFade = 0
        withAnimation(Self.popSpring) { titleScale = 1 }
        withAnimation(Self.popFade) { titleFade = 1 }
    }

    /// The 40ms delay is what makes the pair read as one system with the title
    /// leading. It stays when the caption pops alone, where it is invisible.
    private func popCaption() {
        captionScale = 0.94
        captionFade = 0
        withAnimation(Self.popSpring.delay(0.04)) { captionScale = 1 }
        withAnimation(Self.popFade.delay(0.04)) { captionFade = 1 }
    }

    /// How much wash is present, for twilight to yield to.
    private var washAmount: Double {
        let sky = model.weather(atAbsoluteHour: model.focusHour)
        return WeatherWash.amount(precipitation: sky.precipitation, lightning: sky.lightning)
    }

    private var effectiveScheme: ColorScheme {
        appearance.colorScheme ?? systemScheme
    }

    private var titleColor: Color {
        guard effectiveScheme == .light else { return Theme.ink }
        return ContrastHold.color(ContrastHold.ink, target: Self.titleContrast, on: headerLuminance)
    }

    private var captionColor: Color {
        guard effectiveScheme == .light else { return Theme.muted }
        return ContrastHold.color(ContrastHold.muted, target: Self.captionContrast, on: headerLuminance)
    }


    private var isMorning: Bool {
        model.focusHour - Double(model.dayIndex) * 24 < model.focusSolarDay.solarNoon
    }

    /// Everything painted over the background at the top of the screen, in the
    /// order it is drawn. Leaving twilight out of this was a real bug: at full
    /// dusk the ground is 0.386 while this reported 1.000, so the caption was
    /// left at plain grey and measured 1.4:1.
    private var headerLuminance: Double {
        let sky = model.weather(atAbsoluteHour: model.focusHour)
        let elevation = model.elevationDegrees(atAbsoluteHour: model.focusHour)
        let twilight = TwilightBackground.strength(elevationDegrees: elevation)
            * TwilightBackground.peakOpacity
            * (1 - min(washAmount / WeatherWash.stormPeak, 1))
        return WeatherWash.topLuminance(
            precipitation: sky.precipitation,
            lightning: sky.lightning,
            twilight: (TwilightBackground.lightTopColor(isMorning: isMorning), twilight)
        )
    }

    /// Both roles hold a fixed contrast against the measured ground, so the
    /// gap between them is the same in every condition. Capping the title as
    /// well as raising it is the point: letting it run to 15:1 on a clear day
    /// while the caption is pinned is what let them meet at dusk.
    private static let titleContrast: Double = 9.0
    private static let captionContrast: Double = 3.5

    private var hourOfDay: Double {
        model.focusHour - Double(model.dayIndex) * 24
    }

    /// Carries the day change, since the arc itself deliberately doesn't.
    private var subtitle: String {
        if let active = model.activeEvent {
            // Date first, time last: the title already names the event, so the
            // caption reads as context then the moment it happens.
            return "\(Self.dayLine(model.focusDate)) · \(ArcContent.clock(active.startHour - Double(model.dayIndex) * 24))"
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

    /// A jump pans EVERY layer, and the distance is set by the gap between
    /// events while the duration was fixed. A one-hour hop travelled 130pt and
    /// an eight-hour one 1040pt, both in 0.55s, so the far end smeared at about
    /// 3000 pt/s against a readable 800 to 1200. The capsule arriving mid-smear
    /// is what read as it being dragged along.
    private func jump(to event: CalendarEvent?) {
        guard let event else { return }
        let distance = abs(event.startHour - model.focusHour) * (UIScreen.main.bounds.width / DayModel.windowHours)

        switch jumpStyle {
        case .capsuleLast:
            // Hold the destination back so it appears rather than sweeps.
            suppressedEventID = event.id
            springTo { model.focusHour = event.startHour }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(430))
                withAnimation(.spring(response: 0.26, dampingFraction: 0.62)) {
                    suppressedEventID = nil
                }
            }

        case .speedLimited:
            // Hold a constant readable speed, and simply cut when the gap is
            // too far to cross legibly at all.
            let readableSpeed: Double = 1_000
            let duration = distance / readableSpeed
            if duration > 0.95 {
                model.focusHour = event.startHour
            } else {
                withAnimation(.spring(response: max(0.26, min(duration, 0.9)), dampingFraction: 0.9)) {
                    model.focusHour = event.startHour
                }
            }

        case .dissolve:
            // Keep the direction, lose the middle of the journey.
            withAnimation(.easeIn(duration: 0.10)) { arcFade = 0.12 }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                model.focusHour = event.startHour
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(.easeOut(duration: 0.22)) { arcFade = 1 }
            }
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
