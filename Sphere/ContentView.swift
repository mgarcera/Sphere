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
    @State private var captionScale: CGFloat = 1
    @State private var allDayScale: CGFloat = 1
    /// Mirrors model.allDayEvents.count. The branch below reads THIS, not the
    /// model, so the row's appearance and disappearance always happen inside
    /// a transaction we control.
    @State private var allDayCount = 0
    @AppStorage("appearance") private var appearance: Appearance = .system
    @State private var eventsHidden = false
    @State private var isAllDayOpen = false
    @State private var isDayPickerOpen = false
    @State private var pickedDay: Date = .now

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

            // Invisible, and behind everything: it only exists to present the
            // event editor from a real view controller.
            EventEditorHost(target: $editorTarget, store: calendar.store) {
                let before = model.timedEvents.count
                reloadAfterEdit()
                Trace.log("reload: timed \(before) -> \(model.timedEvents.count)")
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.25), value: calendar.access)
        .preferredColorScheme(appearance.colorScheme)
        .sheet(isPresented: $isDayPickerOpen) {
            VStack(spacing: 0) {
                DatePicker("", selection: $pickedDay, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(Theme.controlAccent)
                    .padding(.horizontal, 12)
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(Theme.background)
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.hidden)
            .onChange(of: pickedDay) { _, day in
                isDayPickerOpen = false
                // Through travel, so a move of days does not sweep every
                // capsule across the screen on the way.
                travel { model.focus(onStartOf: day) }
            }
        }
        .sheet(isPresented: $isAllDayOpen) {
            AllDaySheet(events: model.allDayEvents) { entry in
                isAllDayOpen = false
                if let event = calendar.occurrence(for: entry.id) {
                    editorTarget = .existing(event)
                }
            }
            // One detent, so it cannot be dragged open. It is a glance, not a
            // list view.
            .presentationDetents([.height(AllDaySheet.height(for: model.allDayEvents.count))])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isMenuOpen) {
            DayMenu(model: model, calendar: calendar, location: location, weather: weather, appearance: $appearance) { isMenuOpen = false }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .task {
            Trace.dump()
            allDayCount = model.allDayEvents.count
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

            ArcWindow(model: model, eventsHidden: eventsHidden)
                // Tapping the day returns you to now. The arc is the one
                // surface big enough to carry a gesture nothing can label,
                // which is what let DATE become a plain printed tap.
                .contentShape(.rect)
                .onTapGesture { travel { model.returnToNow() } }
                .padding(.top, 8)

            Spacer(minLength: 16)

            ClickWheel(
                onRotate: { model.scrub(byRotations: $0) },
                onMenu: { isMenuOpen = true },
                onDate: {
                    pickedDay = model.focusDate
                    isDayPickerOpen = true
                },
                onCentre: openEditor,
                onPrevious: { step(.back) },
                onNext: { step(.forward) }
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
                    // The string changes inside the jump's own withAnimation,
                    // so without this SwiftUI applies the transaction's DEFAULT
                    // content transition and crossfades the old text into the
                    // new one. That was the fade that survived removing the
                    // opacity: it was never ours.
                    .contentTransition(.identity)
                    .font(.display())
                    .foregroundStyle(titleColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // Anchored left, not centre: the pair share a left edge and
                    // scaling about the middle would slide them off it.
                    .scaleEffect(titleScale, anchor: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(model.activeEvent == nil)

            Text(subtitle)
                .contentTransition(.identity)
                .font(.footnote)
                .foregroundStyle(captionColor)
                .monospacedDigit()
                .scaleEffect(captionScale, anchor: .leading)

            // The row is always reserved, present or not. Letting it appear
            // and vanish shifted the whole arc down and back as you scrubbed
            // across a day with a birthday on it, and squeezed the title.
            Group {
                if allDayCount == 0 {
                    Color.clear.transition(.identity)
                } else {
                    Button { isAllDayOpen = true } label: {
                        HStack(spacing: 6) {
                            ClockFace(hour: hourOfDay)
                                .stroke(captionColor, style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                                .frame(width: 14, height: 14)
                            Text("\(allDayCount) all day")
                                .contentTransition(.identity)
                                .font(.footnote)
                                .foregroundStyle(captionColor)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    // Pattern 5 in reverse: the branch gets a transition
                    // whether or not we ask, so REPLACE the default rather
                    // than remove it. Scale alone, to nothing and back, so it
                    // pops in and out instead of fading. A scale that stops
                    // short of zero would still cut at that size.
                    .transition(.scale(scale: 0.01, anchor: .leading))
                }
            }
            .frame(height: 16, alignment: .leading)
            .scaleEffect(allDayScale, anchor: .leading)
            .padding(.top, 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .onChange(of: titleKey) { _, _ in popTitle() }
        .onChange(of: captionKey) { _, _ in popCaption() }
        .onChange(of: allDayKey) { _, _ in popAllDay() }
        // The row appears and disappears from HERE, never from the model
        // directly.
        //
        // A transition needs an animated transaction at the moment the
        // hierarchy changes. Jumping supplied one, because `travel` wraps the
        // change in withAnimation, so the pop worked there. Scrubbing does not
        // — the wheel moves focusHour with no transaction — and an
        // `.animation(_:value:)` reading a computed property off the
        // @Observable did not cover it: the insertion and removal were never
        // attributed to that value. Mirroring the count into @State and
        // mutating it inside withAnimation makes every path identical.
        .onChange(of: model.allDayEvents.count) { previous, count in
            // The 80ms delay is the cascade's third beat, and it belongs only
            // to arriving. On the way out there is nothing to be third behind,
            // so the same delay just reads as lag.
            let arriving = previous == 0 && count > 0
            withAnimation(arriving ? Self.popSpring.delay(0.08) : Self.popSpring) {
                allDayCount = count
            }
        }
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

    /// The all-day row changes with the DAY, not with the event under the dot,
    /// so moving between two timed events leaves it still.
    private var allDayKey: String {
        "\(Self.dayLine(model.focusDate))|\(model.allDayEvents.count)"
    }

    /// Drop to 94% and spring back. No fade: the text cuts to its new value
    /// and the bounce carries the change on its own. Scale is a leaf modifier
    /// driven from a discrete change, so the body runs once per pop and Core
    /// Animation does the rest.
    private static let popSpring = Animation.spring(response: 0.26, dampingFraction: 0.62)

    private func popTitle() {
        titleScale = 0.94
        withAnimation(Self.popSpring) { titleScale = 1 }
    }

    /// The 40ms delay is what makes the pair read as one system with the title
    /// leading. It stays when the caption pops alone, where it is invisible.
    private func popCaption() {
        captionScale = 0.94
        withAnimation(Self.popSpring.delay(0.04)) { captionScale = 1 }
    }

    /// Third in the cascade, another 40ms behind the caption.
    private func popAllDay() {
        allDayScale = 0.94
        withAnimation(Self.popSpring.delay(0.08)) { allDayScale = 1 }
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
            // Date first, times last: the title already names the event, so the
            // caption reads as context then when it runs.
            let offset = Double(model.dayIndex) * 24
            let start = ArcContent.clock(active.startHour - offset)
            // A zero-length event would otherwise read "1:24 PM – 1:24 PM".
            guard active.durationHours > 1.0 / 60 else {
                return "\(Self.dayLine(model.focusDate)) · \(start)"
            }
            let end = ArcContent.clock(active.endHour - offset)
            return "\(Self.dayLine(model.focusDate)) · \(start) – \(end)"
        }
        return Self.dayLine(model.focusDate)
    }

    // MARK: - Actions

    /// After an edit, not a scroll: resets the store first so a write is
    /// actually visible.
    private func reloadAfterEdit() {
        let range = model.loadedRange
        calendar.refreshSources()
        calendar.reloadAfterEdit(from: range.start, to: range.end, anchor: model.anchor)
        model.events = calendar.events
    }

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
            Trace.log("editing existing '\(event.title ?? "?")' id=\(event.eventIdentifier ?? "nil") calendar=\(event.calendar?.title ?? "nil")")
            editorTarget = .existing(event)
        } else {
            Trace.log("NEW editor: active=\(model.activeEvent?.title ?? "none") occurrence=\(model.activeEvent.flatMap { calendar.occurrence(for: $0.id) } != nil)")
            editorTarget = .new(model.focusDate)
        }
    }

    /// A jump pans EVERY layer, and the distance is set by the gap between
    /// events while the duration was fixed. A one-hour hop travelled 130pt and
    /// an eight-hour one 1040pt, both in 0.55s, so the far end smeared at about
    /// 3000 pt/s against a readable 800 to 1200. The capsule arriving mid-smear
    /// is what read as it being dragged along.
    /// Chevrons move the time cursor to the next or previous event's START.
    ///
    /// The near list only spans the drawn window, so when it comes up empty the
    /// store is asked over a much wider range before giving up. Without that,
    /// an event further out than a day was unreachable: the jump did nothing,
    /// the focus stayed put, and nothing triggered a reload to widen the view.
    private func step(_ direction: CalendarService.Direction) {
        if let near = direction == .forward ? model.nextEvent : model.previousEvent {
            travel { model.focusHour = near.startHour }
            return
        }
        guard let far = calendar.nearestTimedEvent(direction, from: model.focusDate) else { return }
        travel { model.focusHour = far.startDate.timeIntervalSince(model.anchor) / 3600 }
    }

    /// Every way of moving the dot a long way at once goes through here.
    ///
    /// Moving the focus hour pans the whole arc, so every capsule crosses the
    /// screen on the way — which is most of what a long move looks like. They
    /// are all held back for the flight and revealed on arrival.
    ///
    /// Critically damped, both on the pan and the reveal: a move should land,
    /// not settle. The reveal hangs off the animation's own completion rather
    /// than a timer; a timer is a guess at when a spring settles, and it goes
    /// stale the moment the spring is retuned.
    ///
    /// One function, because NOW and the chevrons do the same thing and the
    /// suppression was written at one call site and not the other.
    private func travel(_ change: () -> Void) {
        eventsHidden = true
        withAnimation(.spring(response: 0.5, dampingFraction: 1), completionCriteria: .removed) {
            change()
        } completion: {
            withAnimation(.easeOut(duration: 0.22)) { eventsHidden = false }
        }
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
