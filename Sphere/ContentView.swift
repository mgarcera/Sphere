import EventKit
import SmidgecraftKit
import SwiftUI
import WidgetKit

struct ContentView: View {
    /// Ordinary at launch, and a fixed fictional day during a capture run (`DemoDay`).
    @State private var model = DemoDay.model()
    @State private var calendar = CalendarService()
    @State private var location = LocationService()

    /// Which of two situations the reader is in. Sphere has no iCloud, so the gate needs no cloud
    /// probe: there is nothing that could arrive, the answer is immediate, and the waiting line,
    /// the escape and the late-arrival screen are all unreachable here by construction.
    ///
    /// `localCount` reports calendar access rather than a row count, because that is what "this
    /// reader has used Sphere before" means in an app with no store. Anyone who already granted
    /// or denied calendar predates the completed flag and must not be shown onboarding again.
    @State private var gate: FirstRunGate?
    @State private var weather = WeatherService()
    @State private var notifications = EventNotifications()
    @Environment(\.scenePhase) private var scenePhase
    @State private var editorTarget: EventTarget?
    @State private var isMenuOpen = false
    @State private var titleScale: CGFloat = 1
    @State private var captionScale: CGFloat = 1
    /// Which quarter-hour the drag last clicked at, so a click fires on
    /// crossing rather than on every frame of the drag.
    @State private var lastDetent: Double = 0
    @State private var allDayScale: CGFloat = 1
    /// Mirrors model.allDayEvents.count. The branch below reads THIS, not the
    /// model, so the row's appearance and disappearance always happen inside
    /// a transaction we control.
    @State private var allDayCount = 0
    @AppStorage("appearance") private var appearance: Appearance = .sky
    @AppStorage(Haptics.key) private var hapticsEnabled = true
    @State private var eventsHidden = false
    @State private var isAllDayOpen = false
    @State private var isDayPickerOpen = false
    @State private var isEventChoiceOpen = false
    @State private var isTimeChoiceOpen = false
    @State private var isCornerChoiceOpen = false
    /// The corner readout says where you are and nothing says it can be pressed (Mason,
    /// 2026-10-16). It names the gesture once, the first time it appears.
    ///
    /// ONCE PER LAUNCH, not once ever, and `@State` rather than `@AppStorage` is the whole of
    /// that decision. A persisted flag teaches the person who set up the phone and nobody else
    /// who ever picks it up, which was the standing objection to a hint at all. Per launch, it
    /// costs a returning reader one two-second label and teaches every new one.
    @State private var nowHintSeenThisLaunch = false
    @State private var showsNowHint = false
    /// Acted on after the chooser closes, never while it is closing: presenting
    /// the editor into a sheet still dismissing is the refusal that cost ten
    /// seconds once already.
    @State private var pendingChoice: EventChoice?
    /// What the New/Open sheet is deciding about (Mason, 2026-10-10).
    ///
    /// The header button asks about the event under the DOT and creates at the focus, which is
    /// all a wheel could say. A tap asks about the event under the FINGER and creates at the
    /// time under the finger, and the two differ by however far the tap was from the centre of
    /// the screen. So the sheet carries both answers with it rather than reading the model when
    /// it closes.
    private struct ChoiceContext {
        let event: EKEvent
        let start: Date
    }
    @State private var choiceContext: ChoiceContext?
    /// Same discipline as `pendingChoice`: acted on after the sheet has closed, never while it
    /// is closing, because the day picker is itself a sheet and presenting into a dismissing one
    /// is the refusal that cost ten seconds once already.
    @State private var pendingTimeChoice: TimeChoice?
    /// Same discipline again, for the hold's own pair (Now / Menu, 2026-10-13). The menu is a
    /// sheet, so choosing it while this one is still dismissing is the same refusal.
    /// Held like the other three, and for the sharper version of the same reason: both of this
    /// pair's answers are sheets, so acting before this one has closed would present a sheet
    /// into a sheet that is still dismissing.
    @State private var pendingCornerChoice: CornerChoice?
    /// Where a Create from that sheet starts. A tap fills it with the time under the finger.
    /// Nothing else fills it any more: the hold, which had no location to give and used the
    /// focus instead, no longer offers Create.
    @State private var timeChoiceStart: Date?
    @State private var pickedDay: Date = .now
    /// Which side of the horizon the Sky mode is on.
    ///
    /// Held in state rather than read from `typeNight` so the flip can be made
    /// with animations explicitly off. A scrub crosses sunset inside
    /// an animated transaction, and everything in a transaction animates
    /// whether or not you asked — a palette crossfade is precisely what this
    /// mode exists not to do.
    @State private var skyIsNight = false
    /// Shown once, when the onboarding hands over. The menu mark in the trailing corner reaches
    /// it through the Guide card, which since 2026-10-13 is one press rather than none.
    @AppStorage("teachGhostSeen") private var guideSeen = false
    @State private var isGuideOpen = false

    /// The window's size, so a detent can be capped against the screen it is opening on. The
    /// sheets are attached here rather than inside `day`, so this is the only place that knows.
    @State private var screenSize: CGSize = .zero
    /// The same test the layout uses, against the window rather than the day area. A screen tall
    /// enough to stack is tall enough for a bottom sheet.
    ///
    /// Named for the height it measures rather than for the orientation it used to mean: the
    /// Duo's inner display is landscape and is NOT short, and a name that said otherwise would
    /// have been read as an orientation check by the next person (2026-10-10).
    private var isShortScreen: Bool {
        screenSize.height > 0 && screenSize.height < Self.stackedMinimumHeight
    }

    /// Never taller than most of the screen. Every detent below was a constant chosen against
    /// an 874-point portrait screen; landscape gives them 402, where 300 is three quarters of
    /// the view and the day picker's 420 was taller than the screen outright (2026-10-10).
    private func detent(_ ideal: CGFloat) -> CGFloat {
        guard screenSize.height > 0 else { return ideal }
        return min(ideal, max(180, screenSize.height * 0.85))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            // One colour, edge to edge, from where the sun is. It replaced ClearBlue's ramp,
            // TwilightBackground's wash and NightSky's shaped fill in one pass (DECISIONS,
            // 2026-10-09).
            SkyField(elevationDegrees: focusElevation,
                     clearness: model.clearness(atAbsoluteHour: model.focusHour),
                     suppressedBy: washAmount / WeatherWash.stormPeak)

            let sky = model.weather(atAbsoluteHour: model.focusHour)


            // Weather sits over the time of day, being nearer.
            WeatherWash(precipitation: sky.precipitation, lightning: sky.lightning)

            if let gate, gate.hasResolved, gate.state == .new, !DemoDay.isEnabled {
                // Three screens, the first two each immediately before the thing they explain,
                // and a handover after them. The screen this
                // replaced explained both permissions and then raised both prompts back to back,
                // so the location one arrived with its reason two screens of attention earlier
                // (2026-10-04).
                FirstRunFlow(calendar: calendar, location: location) {
                    // The one animation this swap is allowed, and it is explicit: the reader
                    // pressed Start, the app is active, nothing is waiting on an alert.
                    withAnimation(.easeInOut(duration: 0.6)) { gate.markOnboardingComplete() }
                    reload()
                    // The guide rises AFTER the fade rather than through it, so the arc is what
                    // Start reveals and the gestures arrive over a day that is already there
                    // (Mason, 2026-10-10).
                    guideSeen = true
                    Task {
                        try? await Task.sleep(for: .milliseconds(700))
                        isGuideOpen = true
                    }
                }
                .transition(.opacity)
            } else {
                day
                    .transition(.opacity)
            }

            // Landscape's answer to the four choice sheets. Same cards, same callbacks, and the
            // same dismissal discipline — the choice is held and acted on after the panel is
            // gone, because the day picker and the editor are sheets and presenting one into a
            // view that is still leaving is the refusal that cost ten seconds once already.
            if isShortScreen, isTimeChoiceOpen {
                ChoicePanel {
                    withAnimation(.easeOut(duration: 0.2)) { isTimeChoiceOpen = false }
                } cards: {
                    TimeChoiceSheet.cards { choice in
                        pendingTimeChoice = choice
                        withAnimation(.easeOut(duration: 0.2)) { isTimeChoiceOpen = false }
                        actOnTimeChoice()
                    }
                }
            }

            if isShortScreen, isEventChoiceOpen {
                ChoicePanel {
                    withAnimation(.easeOut(duration: 0.2)) { isEventChoiceOpen = false }
                } cards: {
                    EventChoiceSheet.cards { choice in
                        pendingChoice = choice
                        withAnimation(.easeOut(duration: 0.2)) { isEventChoiceOpen = false }
                        actOnEventChoice()
                    }
                }
            }

            if isShortScreen, isCornerChoiceOpen {
                ChoicePanel {
                    withAnimation(.easeOut(duration: 0.2)) { isCornerChoiceOpen = false }
                } cards: {
                    CornerChoiceSheet.cards { choice in
                        pendingCornerChoice = choice
                        withAnimation(.easeOut(duration: 0.2)) { isCornerChoiceOpen = false }
                        actOnCornerChoice()
                    }
                }
            }

            // Invisible, and behind everything: it only exists to present the
            // EventKit controllers from a real view controller.
            EventKitHost(target: $editorTarget, store: calendar.store) {
                reloadAfterEdit()
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.25), value: calendar.access)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { screenSize = $0 }
        .task {
            guard gate == nil else { return }
            let calendarService = calendar
            let g = FirstRunGate(
                localCount: { await MainActor.run { calendarService.access == .undetermined ? 0 : 1 } },
                cloud: nil
            )
            gate = g
            await g.resolve()
        }
        // The status bar reads the HOSTING CONTROLLER's style, and
        // `preferredColorScheme` is the only lever SwiftUI gives onto it —
        // `UIStatusBarStyle.default` claims to adapt to the content below it
        // and in practice only ever moved the battery.
        //
        // So the scheme goes dark at night, and the app's own colours are
        // pinned straight back underneath it. The palette is asset pairs, so
        // without the pin the ground below the horizon would inherit the dark
        // side and the whole app would flip — which is the thing this sky was
        // built to avoid doing.
        .preferredColorScheme(preferredScheme)
        .environment(\.colorScheme, effectiveScheme)
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
            .presentationDetents([.height(detent(420))])
            .presentationDragIndicator(.hidden)
            .onChange(of: pickedDay) { _, day in
                isDayPickerOpen = false
                // Through travel, so a move of days does not sweep every
                // capsule across the screen on the way.
                travel { model.focus(onStartOf: day) }
            }
        }
        .sheet(isPresented: $isGuideOpen) {
            GestureGuide()
                .presentationDetents([.height(detent(GestureGuide.height))])
                // Hidden, like every other sheet here — eight of them now, two when this was
                // written (Mason, 2026-10-10). It was shown for one build on
                // the argument that a sheet which is read rather than answered owes a visible
                // way out; a grabber over a page of hands is one more mark competing with the
                // six being demonstrated, and a sheet drags down whether or not it says so.
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: Binding(get: { isTimeChoiceOpen && !isShortScreen },
                                    set: { isTimeChoiceOpen = $0 }), onDismiss: {
            actOnTimeChoice()
        }) {
            TimeChoiceSheet { choice in
                pendingTimeChoice = choice
                isTimeChoiceOpen = false
            }
            .presentationDetents([.height(TimeChoiceSheet.height)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: Binding(get: { isEventChoiceOpen && !isShortScreen },
                                    set: { isEventChoiceOpen = $0 }), onDismiss: {
            actOnEventChoice()
        }) {
            EventChoiceSheet { choice in
                pendingChoice = choice
                isEventChoiceOpen = false
            }
            .presentationDetents([.height(EventChoiceSheet.height)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: Binding(get: { isCornerChoiceOpen && !isShortScreen },
                                    set: { isCornerChoiceOpen = $0 }), onDismiss: {
            actOnCornerChoice()
        }) {
            CornerChoiceSheet { choice in
                pendingCornerChoice = choice
                isCornerChoiceOpen = false
            }
            .presentationDetents([.height(CornerChoiceSheet.height)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isAllDayOpen) {
            AllDaySheet(events: model.allDayEvents) { entry in
                isAllDayOpen = false
                if let event = calendar.occurrence(for: entry.id) {
                    Sounds.ring(.editor)
                    editorTarget = .existing(event)
                }
            }
            // One detent, so it cannot be dragged open. It is a glance, not a
            // list view.
            .presentationDetents([.height(detent(AllDaySheet.height(for: model.allDayEvents.count)))])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isMenuOpen) {
            DayMenu(model: model, calendar: calendar, location: location, weather: weather, notifications: notifications, appearance: $appearance) { isMenuOpen = false }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .task {
            allDayCount = model.allDayEvents.count
            // Ask independently of priming. Anyone who granted calendar before
            // location existed never sees that screen again, and was silently
            // getting Chicago's sky.
            // NOT here (Mason, 2026-10-10). This raised the location prompt the instant the app
            // launched, on top of the first-run flow's own calendar screen — two asks at once,
            // which is the thing FirstRunFlow was split in two to avoid (2026-10-04), and it is
            // not what the words on screen were talking about. The flow's weather step asks;
            // `requestLocationIfPastOnboarding` below covers every later launch.
            // A capture run supplies all three inputs itself and then stops: no fetch, no
            // calendar read, and no `tick()`, because the dot must stay where the scene put it
            // rather than walking to the real now while the shot is being taken.
            guard !DemoDay.isEnabled else {
                allDayCount = DemoDay.apply(to: model, weather: weather)
                return
            }
            await weather.load(coordinate: location.coordinate)
            model.applySky(from: weather)
            reload()
            await notifications.refreshPermission()
            await rescheduleNotifications()
            model.tick()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                model.tick()
            }
        }
        // Someone editing in Calendar.app would otherwise leave the arc stale. It is also the only
        // signal a notification schedule can be rebuilt from: EKEventStoreChanged is an
        // NSNotification on the default center, so it arrives only while Sphere is running.
        .task {
            for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
                reload()
                await rescheduleNotifications()
            }
        }
        .onChange(of: model.dayIndex) { _, _ in
            reload()
            model.applySky(from: weather)
        }
        // Three separate triggers because each is a different event, and the schedule is torn
        // down and rebuilt either way: the toggle, the lead time, and the system prompt's answer
        // arriving (which is asynchronous, so the toggle flipping on cannot schedule by itself).
        // Returning to the foreground is its own trigger. EKEventStoreChanged is posted inside a
        // running process, so an event created in Calendar.app while Sphere was suspended is never
        // heard, and before this the schedule was only rebuilt at launch.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await notifications.refreshPermission()
                reload()
                await rescheduleNotifications()
            }
        }
        .onChange(of: notifications.isEnabled) { _, _ in Task { await rescheduleNotifications() } }
        .onChange(of: notifications.leadMinutes) { _, _ in Task { await rescheduleNotifications() } }
        .onChange(of: notifications.permission) { _, _ in Task { await rescheduleNotifications() } }
        // A fix moves the whole arc, since the curve is the sun's elevation
        // where you actually are.
        .onChange(of: location.timeZone) { _, _ in relocate() }
        .onChange(of: location.coordinate) { _, coordinate in
            model.relocate(to: coordinate, timeZone: location.timeZone)
            Task {
                await weather.load(coordinate: coordinate)
                model.applySky(from: weather)
            }
        }
        .onChange(of: calendar.hiddenSourceIDs) { _, _ in reload() }
        // For someone already past the onboarding: the flow is where a first run is asked, and
        // this is the only other place that asks.
        .onChange(of: gate?.hasResolved) { _, _ in requestLocationIfPastOnboarding() }
        .onChange(of: gate?.state) { _, _ in requestLocationIfPastOnboarding() }
    }

    /// Two arrangements, because landscape is a different shape rather than a smaller one.
    ///
    /// The measurement that forced it: in landscape the window is 874x402, the arc block is 322
    /// tall, so it spans y 36 to 358 — and its SKY GUTTER, the top 100 points where the cloud
    /// decks draw, is y 36 to 136. The header occupied y 36 to 112. It was not sitting over the
    /// arc, it was sitting in the clouds, and no amount of padding fixes that because there is
    /// no vertical room left to find. Landscape's room is horizontal (2026-10-10).
    private var day: some View {
        GeometryReader { proxy in
            if proxy.size.height < Self.stackedMinimumHeight {
                shortScreenDay(width: proxy.size.width)
            } else {
                portraitDay
            }
        }
        // Here rather than on `nowButton`, which is built by both layouts: only one of them
        // exists at a time, but a trigger that fires once belongs above the thing that chooses.
        .onChange(of: model.isFocusedOnNow) { _, onNow in
            if onNow {
                // Pressed it, or scrubbed back by hand. Either way the lesson is over.
                showsNowHint = false
            } else if !nowHintSeenThisLaunch {
                nowHintSeenThisLaunch = true
                showsNowHint = true
            }
        }
        // `id:` is the point: returning to now sets `showsNowHint` false, which tears this down
        // and cancels the sleep, so a hint that has already been answered cannot fire its own
        // dismissal two seconds later.
        .task(id: showsNowHint) {
            guard showsNowHint else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            showsNowHint = false
        }
    }

    /// Below this, the header and the arc go side by side; at or above it they stack.
    ///
    /// The test is HEIGHT, not orientation (Mason, 2026-10-10: the Duo's inner display in
    /// landscape has the room, and columns there are solving a problem it does not have). The
    /// arithmetic: the arc block is 322 tall and centres in the space, so its top sits at
    /// (H - 322) / 2, and the header runs from 12 down to about 112 with no all-day events. The
    /// header clears the block's sky gutter — the band the clouds draw in — when
    /// 112 <= (H - 322) / 2, which is H >= 546. 560 for air.
    ///
    /// A regular iPhone in landscape has 382 and gets columns; the Duo's inner display has about
    /// 640 and stacks. The honest caveat: three all-day events push the header to about 170,
    /// which needs 662, so at the bottom of the stacked range a full header reaches into the
    /// gutter again. That is a smaller fault than columns on a screen with room to spare.
    private static let stackedMinimumHeight: CGFloat = 560

    /// Two columns, for a screen without the height to stack. The header takes a column and
    /// stops competing for height; nothing is scaled down and nothing is clipped.
    private func shortScreenDay(width: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            header
                .frame(width: Self.headerColumn(in: width), alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 12)

            arcBlock
                .modifier(ScrubAffordance())
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottomLeading) { nowButton }
        .overlay(alignment: .bottomTrailing) { cornerButton }
    }

    /// Wide enough for the longest line the header sets — the date, about 130 points — with room
    /// for an event title to wrap once, and never more than a third of the screen, because what
    /// is left is what the arc has to draw a day in.
    private static func headerColumn(in width: CGFloat) -> CGFloat {
        min(300, max(220, width * 0.32))
    }

    private var portraitDay: some View {
        // One arrangement WITHIN portrait (Mason, 2026-10-09: an overlay is fine in landscape).
        // Landscape has had its own branch since 2026-10-10; see `day` above, which chooses
        // between this and `shortScreenDay` on the available height.
        // The arc centres in the WHOLE space and the header sits over it, rather than above it
        // in the flow — in the flow, the header's height was subtracted from the space the arc
        // centred in, so gaining an all-day event grew the header and pushed the arc down by
        // half that growth. The drawing moved because a list did.
        arcBlock
            // The arc's content fades at both edges, which is true — there IS more day that
            // way — and is the one signifier a horizontally scrolling surface has.
            .modifier(ScrubAffordance())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                header
                    .padding(.top, 12)
            }
            // For anyone already past the onboarding when this arrived: the guide has its own
            // opening from there, and this covers the readers that opening will never reach.
            .task {
                guard !guideSeen, !DemoDay.isEnabled else { return }
                guideSeen = true
                try? await Task.sleep(for: .milliseconds(900))
                isGuideOpen = true
            }
            .padding(.vertical, 24)
            // Dim, for the reasons on `cornerButton` itself, which is where that argument lives
            // and where the 0.3 → 0.55 change of 2026-10-13 is recorded. This call site carried
            // a verbatim copy of the retired version of it.
            //
            // The two swapped sides on 2026-10-16 (Mason): the readout leads, the menu trails.
            .overlay(alignment: .bottomLeading) { nowButton }
            .overlay(alignment: .bottomTrailing) { cornerButton }
    }

    /// Dim, and the one exception to "no greys": its job is to stay out of the way until someone
    /// is looking for it. The day menu carried this for one build and nobody opens a menu row
    /// until they are already stuck.
    ///
    /// It was 0.3 of the mark colour until 2026-10-13 and Mason could not see it. 0.55 roughly
    /// doubles the contrast against the paper while still reading as secondary to everything the
    /// arc draws. The dimness was set when this button's only job was to replay a guide that had
    /// just played itself; it is now also the only visible route to the menu, so being ignorable
    /// is worth less than being findable. Full ink was the other way to answer it, and would end
    /// the "no greys" exception rather than soften it, at the cost of one permanent black mark on
    /// a canvas that carries nothing else.
    ///
    /// It asks Menu or Guide as of 2026-10-16, and asked Guide or Menu from 2026-10-13, rather
    /// than opening the guide outright, because the menu had been left with no visible route at
    /// all; `CornerChoiceSheet` holds that argument and the cost of it. The two automatic
    /// openings of the guide, at the end of onboarding and once for anyone already past it, still
    /// go straight to `isGuideOpen` and never through the cards: an explanation that arrives by
    /// itself cannot ask a question first.
    ///
    /// **It draws `.menu` rather than an SF `questionmark`, and it sits on the TRAILING side**
    /// (Mason, 2026-10-16), having been a question mark on the leading side for as long as it
    /// existed. Two concerns were raised before the change and neither was decisive; both are
    /// recorded because the first contradicts an argument this app made in 2.0.
    ///
    /// One: the "?" existed so the guide would be findable, since burying it in a menu had been
    /// tried and "C proved it would not be found" (DECISIONS, 2.0). A menu glyph opening a pair
    /// led by Menu is closer to buried than a question mark was. What holds it down is unchanged
    /// and is still two things rather than three: the guide rises by itself when the onboarding
    /// hands over and once more for anyone already past it, and the hold reaches the same pair.
    ///
    /// Two: this mark and the leading card of the sheet it opens are now the same drawing, so a
    /// press on a menu glyph is answered by a card labelled Menu, which can read as the press
    /// not having landed.
    ///
    /// Drawn at 20 points with a 1.5 line, which puts its three strokes at about 9.5 points
    /// overall against the 9.3-point cap height of the 13-point semibold readout in the other
    /// corner. The two corners are a pair and the pair is measured rather than eyeballed.
    private var cornerButton: some View {
        Button {
            isCornerChoiceOpen = true
        } label: {
            ActionMark(mark: .menu, size: 20, color: markColour.opacity(0.55), stroke: 1.5)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // An `ActionMark` is a `Canvas`, so it publishes no name at all and this label is the
        // only thing VoiceOver has. It used to be an override: the SF Symbol announced itself as
        // "questionmark", which was never apt (Mason, 2026-10-13). The second
        // `accessibilityLabel` in the app; the first is the guide's page counter.
        .accessibilityLabel("Menu or guide")
        .padding(.trailing, 8)
        .padding(.bottom, 4)
    }

    /// Back to the present, in the corner opposite the menu mark (Mason, 2026-10-16). It was
    /// bottom-trailing with the menu bottom-leading for its first three builds; the two swapped
    /// the same day, so the readout leads and the menu trails.
    ///
    /// Why it is not on the arc, which was the native-looking answer: scrub out to Thursday
    /// afternoon and the now-dot is off the drawing. That is the exact moment a way back is worth
    /// a press, so a mark drawn at the present instant is missing whenever it would be used.
    ///
    /// Why it is not above a sheet: a sheet asks about the time under your finger and Now throws
    /// that time away, so a Now button over an open sheet is a second answer to a question
    /// already on screen. A sheet covers this, which is correct.
    ///
    /// It is CONDITIONAL, which is what makes the corner affordable. Two permanent marks start a
    /// toolbar on a canvas that carries almost nothing, and that cost is why the corner button
    /// took a fork rather than a neighbour (`CornerChoiceSheet`). Hidden while the focus is on now, this is
    /// not furniture: it is a way back, absent exactly when it would say nothing. `isFocusedOnNow`
    /// is a one-minute window, so it appears on the first detent of a scrub.
    ///
    /// Opacity rather than an `if`, and hit testing off with it, for the reason written on the
    /// header's title button: this way there is nothing to transition in and no invisible 44pt
    /// target. Full ink rather than the "?"'s 0.55, because this one is a way out of somewhere
    /// rather than a thing to find when stuck, and because it is only ever on screen when it has
    /// something to do.
    ///
    /// It drew the `.now` mark for one build. Mason, 2026-10-16: "i think this icon isn't
    /// recognizable to users" — a half-arc with a dot says "a moment in a day" to someone who
    /// has already learned that the arc is a day, which is nobody on their first scrub. So it
    /// reads out the distance instead (`distanceFromNow`), which states where you are and leaves
    /// what the press does to be inferred from the only thing that can clear a distance. The
    /// conditional visibility is what makes the text affordable: a permanent readout would be a
    /// status bar, and "+0 minutes" says nothing.
    ///
    /// **The affordance, which the readout did not have.** Mason, 2026-10-16: "i think the
    /// wording needs an affordance of some kind though to indicate it can be clicked." The
    /// obvious answers were all boxes, and this app has written down its refusal of the box
    /// twice: `ChoiceCard` dropped its border because "a border around them was drawing the
    /// container rather than the choice", and the palette has no greys but the "?" at 0.55. So
    /// the button names the gesture once instead, for two seconds, the first time it appears in
    /// a launch (`showsNowHint`).
    ///
    /// Mason chose this over setting the readout in amber, which was my recommendation, and over
    /// the cards' uppercase tracked word. The objection I had stands and is worth leaving here:
    /// a hint is a thing that has to be caught, so it teaches whoever happens to be looking the
    /// first time they scrub and nobody else. Once per launch rather than once ever is what
    /// narrows that, and it is the only part of the mechanism that answers it.
    ///
    /// The cost, where it is paid: for those two seconds the first scrub of a launch shows no
    /// distance. Small, because the distance at the start of a scrub is "+15 minutes" and
    /// uninteresting, and because it is the one moment the control matters more than its value.
    ///
    /// **It takes the "?"'s treatment** as of 2026-10-16, so the two bottom corners are one pair
    /// rather than two unrelated controls: same size, same semibold, same 0.55 of the ink. The
    /// cost stated plainly, since it runs against the "?"'s own argument: 0.55 was chosen there
    /// to keep help out of the way until someone looks for it, and this readout's job is the
    /// opposite, to be read mid-scrub. Dimming information is a real price. What buys it is that
    /// the corners now say "these two are the same kind of thing", which is worth more than the
    /// contrast while the alternative was one dim mark and one full-ink one.
    private var nowButton: some View {
        Button {
            goToNow()
        } label: {
            // The subtitle's treatment exactly: footnote, monospaced digits, and `.identity` so
            // the number does not animate. A scrub changes this on every frame, and a numeric
            // content transition on a value that moves continuously is noise rather than motion.
            // ONE `Text` whose string changes, not two crossfading in a `ZStack`. A ZStack sizes
            // to its widest child, so the hit area would stay as wide as the sentence for as
            // long as the button was on screen — a 120-point invisible target in the corner,
            // which is the fault this button's own argument was written to avoid. The cost is
            // that the swap pops rather than fades. It is a deliberate change two seconds in,
            // and it reads as one.
            Text(showsNowHint
                 ? Self.nowHint
                 : Self.distanceFromNow(model.focusDate, from: model.realNow) + " " + Self.tapBack)
                .contentTransition(.identity)
                // The "?"'s treatment, so the two corners read as a pair (Mason, 2026-10-16):
                // 13 points at default type, semibold, and the ink at 0.55 — which is where the
                // "?" landed on 2026-10-13 after 0.3 proved invisible to him.
                //
                // `.footnote.weight(.semibold)` rather than the "?"'s literal
                // `.system(size: 13, weight: .semibold)`. The two are identical at default
                // Dynamic Type and this one grows with the setting, which the "?" does not. A
                // glyph that means "help" survives being pinned at 13 points; a number someone
                // has to read does not.
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(markColour.opacity(0.55))
                .fixedSize()
                .frame(height: 44)
                .padding(.horizontal, 10)
                .contentShape(.rect)
        }
        // The app's press language, the same style every choice card uses: presses dim rather
        // than scale. `.plain` gave this button no press feedback at all for two builds.
        .buttonStyle(DimOnPress())
        .accessibilityLabel("Back to now")
        .opacity(model.isFocusedOnNow ? 0 : 1)
        .allowsHitTesting(!model.isFocusedOnNow)
        .animation(.easeOut(duration: 0.2), value: model.isFocusedOnNow)
        .padding(.leading, 8)
        .padding(.bottom, 4)
    }

    /// The drawing alone. The header and the weather line left for the top of the screen, so
    /// this is free to sit wherever the space allows.
    private var arcBlock: some View {
        ArcWindow(model: model, eventsHidden: eventsHidden,
                      // A flat field has no shaped night, so NightSky never draws. Kept as a
                      // parameter rather than torn out of ArcWindow in the same pass.
                      nightness: 0,
                      nightSuppressedBy: washAmount / WeatherWash.stormPeak,
                      mark: markColour,
                      // STUDY: these two callbacks were shared by the wheel and the drag, so
                      // both landed on one code path and felt identical past the touch. The
                      // wheel went in 2.0 and the drag is the only caller now; the pair is kept
                      // because the shape is what a later control would join (2026-10-13).
                      onScrub: { hours in
                          model.focusHour += hours
                          clickPastDetents()
                      },
                      onScrubBegan: {
                          Haptics.warm()
                          lastDetent = (model.focusHour / Haptics.detentHours).rounded(.towardZero)
                      },
                      onTapTime: openAtTappedHour,
                      // Already clamped against the arc's own width, which is the only place
                      // that knows it.
                      onZoom: { model.windowHours = $0 },
                      // Now or the menu (Mason, 2026-10-13). The hold opened the menu outright
                      // from 2026-10-10; before that it had the time sheet for one build and
                      // lost it to the tap, because a tap carries the time those cards decide
                      // about and a long press reports no location at all. That is still true
                      // and is now the reason this gesture carries BOTH of the actions that
                      // need no aim: back to the present, or the day's menu.
                      // The guide or the menu (Mason, 2026-10-14): the same pair the question
                      // mark in the corner opens, and literally the same sheet rather than a
                      // copy of it. The hold is the gesture with no visible surface, and the two
                      // things behind it are now the two surfaces that explain the app and hold
                      // everything else — neither of which cares where the finger was. Now went
                      // back to the tap on the same day.
                      //
                      // No bell. A modal is a question, and the bells mark what the answer DOES.
                      onHold: { isCornerChoiceOpen = true },
                      // Straight to now (Mason, 2026-10-13), which is the half of the pair
                      // above that gets reached for without thinking. It asks nothing and lands
                      // in one gesture; the menu, being a place rather than a move, is worth the
                      // card. Deliberately the same action the hold's first card runs, through
                      // the same function, so the shortcut cannot drift from what it shortcuts.
                      // The chevrons' own behaviour, which outlived the chevrons: nearest event
                      // in that direction, searched past the drawn window, and a haptic that says
                      // nothing is there when nothing is.
                      onEdgeStep: { direction in
                          step(direction < 0 ? .back : .forward)
                      })
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
            // NOT `.disabled`. A disabled button dims its label, so the time
            // was drawn at reduced opacity whenever the dot was not inside an
            // event — which is most of the day. On paper the old contrast system already
            // held the title short of black and the dimming hid inside that; on
            // a clear sky, where the title runs to pure black, it showed up as
            // the one grey thing in a black header.
            .allowsHitTesting(model.activeEvent != nil)

            Text(subtitle)
                .contentTransition(.identity)
                .font(.footnote)
                .foregroundStyle(captionColor)
                .monospacedDigit()
                .scaleEffect(captionScale, anchor: .leading)

            // Above the all-day events, not below them (Mason, 2026-10-09). The sky is a
            // property of the hour and the all-day rows are a list, so the reading belongs with
            // the date it qualifies rather than under a list whose length changes.
            weatherLine
                .padding(.top, 6)

            // Under the date, in the column, and the weather moved down beneath it so the
            // header ends in the sky line — closer to the clouds it describes. This puts the
            // all-day rows back in the flow that sets the arc's position: a day with events is
            // taller by a line each, and the arc moves with it.
            Group {
                if allDayCount == 0 {
                    // Zero height, explicitly. A bare `Color.clear` is FLEXIBLE: with the block
                    // centred it claimed a third of the slack and pushed the weather line ~390
                    // points below the date (Mason, 2026-10-09). It exists only so the
                    // transition has something to cross-fade against.
                    Color.clear.frame(height: 0).transition(.identity)
                } else {
                    Button { isAllDayOpen = true } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                ClockFace(hour: hourOfDay)
                                    .stroke(captionColor, style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                                    .frame(width: 14, height: 14)
                                Text("\(allDayCount) all day event\(allDayCount == 1 ? "" : "s")")
                                    .contentTransition(.identity)
                                    .font(.footnote)
                                    .foregroundStyle(captionColor)
                            }
                            // The events themselves, under the count, in the sheet's own row:
                            // a dot in the calendar's colour and the title, one line each,
                            // flush with the count so the whole block shares one left edge.
                            ForEach(model.allDayEvents) { event in
                                HStack(spacing: 6) {
                                    // 10pt dot in the same 14pt column the clock glyph and the
                                    // weather glyph occupy, so all three lines' text shares one
                                    // left edge. At 7 in a 7 column the rows sat 7pt left.
                                    Circle()
                                        .fill(event.color)
                                        .frame(width: 10, height: 10)
                                        .frame(width: 14, height: 14)
                                    Text(event.title)
                                        .font(.footnote)
                                        .foregroundStyle(captionColor)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    // Pattern 5 in reverse: the branch gets a transition whether or not we
                    // ask, so REPLACE the default rather than remove it. Scale alone, to
                    // nothing and back, so it pops in and out instead of fading.
                    .transition(.scale(scale: 0.01, anchor: .leading))
                }
            }
            // Two lines reserved whether or not the day has events: a footnote line, the
            // 4pt row spacing, and a second line. The arc never moves for an all-day event.
            // A third event still adds a line — accepted, since the choice was two, not a cap.
            .frame(minHeight: 36, alignment: .topLeading)
            .scaleEffect(allDayScale, anchor: .leading)
            .padding(.top, 5)

            // A spacer, 16 points, and nothing is drawn lower to pair with it: the weather line
            // moved INTO the header on 1ec8f3d and is drawn at `weatherLine` above the all-day
            // rows. This kept the header's height while the line lived over the arc's sky
            // gutter, and is now only the gap under the date (corrected 2026-10-10).
            Color.clear
                .frame(height: 16)
                .padding(.top, 7)

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .onChange(of: titleKey) { _, _ in popTitle() }
        .onChange(of: captionKey) { _, _ in popCaption() }
        .onChange(of: allDayKey) { _, _ in popAllDay() }
        // A cut, not a fade. The parked palette experiment was built on the
        // opposite premise — that crossing sunset under a moving
        // thumb meant the change had to be continuous or it would read as a
        // jump — and it spent a bespoke Palette, staged per-mark turns and a
        // custom ground path trying to survive the crossing. There is no
        // crossing to survive if nothing travels through it.
        .task { skyIsNight = skyNight }
        .onChange(of: skyNight) { _, isNight in
            var cut = Transaction()
            cut.disablesAnimations = true
            withTransaction(cut) { skyIsNight = isNight }
        }
        // The row appears and disappears from HERE, never from the model
        // directly.
        //
        // A transition needs an animated transaction at the moment the
        // hierarchy changes. Jumping supplied one, because `travel` wraps the
        // change in withAnimation, so the pop worked there. Scrubbing does not
        // — a scrub moves focusHour with no transaction — and an
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
        "\(titleKey)|\(Self.dayLine(model.focusDate, in: model.timeZone))"
    }

    /// The all-day row changes with the DAY, not with the event under the dot,
    /// so moving between two timed events leaves it still.
    private var allDayKey: String {
        "\(Self.dayLine(model.focusDate, in: model.timeZone))|\(model.allDayEvents.count)"
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
        if appearance == .sky { return skyIsNight ? .dark : .light }
        return appearance.colorScheme ?? .light
    }

    /// The same crossing the header's type turns on. The Sky mode reads the
    /// RAW turn rather than the gated one below — gated, it would read 0 in
    /// light mode and the mode could never leave day.
    ///
    /// It is not the sky's own 0° to −12°: that schedule was rejected for the
    /// header for leaving type dark on a dimming ground for the best part of an
    /// hour, and it would do the same to a whole palette.
    private var skyNight: Bool { nightTurn > 0.5 }


    /// Whether the header is sitting on sky rather than on paper.
    ///
    /// A clear midday sky is a DARK ground — about a third of paper's luminance
    /// — and light type is what belongs on it. NOT decided on the contrast
    /// ratio: at that ground pure black scores 7.9:1 against white's 2.7:1, so
    /// the arithmetic prefers dark ink the whole way and keeps preferring it
    /// well past the point the screen reads as sky. Same fault as dusk, same
    /// answer: turn on the cause, not on the measurement.
    ///
    /// A cut, like the horizon's. The sky visibly filling with blue is the
    /// author of the change, which is what a discontinuity needs in order to
    /// read as intent rather than as a glitch.
    ///
    /// **Only the system's furniture turns.** The status bar cannot be given a
    /// colour, only a scheme, so it gets the one that reads on the deepest part
    /// of the gradient — which is where it happens to sit.
    ///
    /// Two sentences went from here on 2026-10-13. One had the app's own type driven by
    /// `ContrastHold`, a type deleted on 2026-10-09 when the app became two colours. The other
    /// gave the ratios the wrong way round for what ships: `onBlue` below is true exactly when
    /// the field is light enough for BLACK marks, and `SkyField` measures 6.0:1 for black on the
    /// noon blue. The paragraph above, which decides the polarity on the cause rather than on the
    /// measurement, is the one that is still live.
    /// Whether the field is light enough to carry black marks. This used to ask how much blue
    /// was on screen via `ClearBlue.strength`; with one field and a two-colour ink system the
    /// same question is just which way the polarity fell.
    private var onBlue: Bool { markColour == .black }

    /// Whether a night sky is drawn at all.
    ///
    /// Only where the whole app is dark. Darkening the band above the arc while
    /// the ground below it stayed paper — the half-screen night — is what the
    /// Sky mode replaced: it produced a ~19:1 step across the horizon and two
    /// halves that read as different apps, and every attempt to reconcile them
    /// cost more than flipping the palette outright.
    // `showsNightSky` and `nightness` were deleted here on 2026-10-13, on Mason's word, with
    // every other symbol a reference sweep found unread. `nightness` was this property's only
    // reader and nothing read `nightness`; `ArcWindow` still takes a parameter of that name,
    // receives a literal 0 below, and reads it nowhere. Restoring the pair is
    // `effectiveScheme == .dark`, and `SkyDepth.nightness(elevationDegrees:)` on the focused
    // hour's elevation.

    /// What the status bar is told. Only the Sky mode has anything to say:
    /// every other mode's palette already agrees with the window's.
    private var preferredScheme: ColorScheme? {
        // The system's glyphs sit on the same blue the title does. The app's
        // own palette is pinned straight back underneath by the `colorScheme`
        // environment, so only the furniture follows this.
        if onBlue { return .dark }
        if appearance == .sky { return skyIsNight ? .dark : .light }
        return appearance.colorScheme
    }

    /// What the sky is doing at the focused hour: the mark, the word
    /// and the temperature.
    ///
    /// It follows the focus like the rest of the header — the arc's clouds are
    /// already drawn for the focused hour, so a reading anchored to the real
    /// now would disagree with the picture directly above it.
    @ViewBuilder
    private var weatherLine: some View {
        let condition = model.condition(atAbsoluteHour: model.focusHour)
        let reading = weather.hour(at: model.focusDate)

        HStack(spacing: 6) {
            SkyGlyph(condition: condition ?? .clear)
                .stroke(captionColor, style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
                .frame(width: 14, height: 14)

            Text((condition ?? .clear).title)
                .contentTransition(.identity)
                .font(.footnote)
                .foregroundStyle(captionColor)

            if let celsius = reading?.celsius {
                Text(Self.degrees(celsius))
                    .contentTransition(.identity)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(captionColor)
            }
        }
        // Reserved whether or not the forecast has arrived, for the reason the
        // all-day row is: a line that appears later shifts the whole arc.
        .frame(height: 16, alignment: .leading)
        .opacity(condition == nil ? 0 : 1)
    }

    /// Whole degrees, in the reader's own unit. Fetched in celsius and
    /// localised at the point of display, so the unit follows the reader rather
    /// than the request.
    static func degrees(_ celsius: Double) -> String {
        Measurement(value: celsius, unit: UnitTemperature.celsius)
            .formatted(.measurement(width: .narrow,
                                    usage: .weather,
                                    numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    /// The crossing itself, ungated: 0 above the horizon, 1 below, over about
    /// two degrees.
    private var nightTurn: Double {
        let t = ((1 - focusElevation) / 2).clamped(to: 0...1)
        return t * t * (3 - 2 * t)
    }

    private var focusElevation: Double {
        model.elevationDegrees(atAbsoluteHour: model.focusHour)
    }

    /// Pure black or pure white, whichever the field can carry. Everything drawn ON the field
    /// reads this: title, caption, weather, the curve, the sun, the labels, the ticks.
    private var markColour: Color { SkyField.mark(on: fieldColour) }

    /// The field's colour right now, for anything that has to sit on it.
    private var fieldColour: Color {
        SkyField.colour(elevationDegrees: focusElevation,
                        clearness: model.clearness(atAbsoluteHour: model.focusHour),
                        suppressedBy: washAmount / WeatherWash.stormPeak,
                        dark: effectiveScheme == .dark)
    }

    /// Black or white, never between. `ContrastHold` used to hold 9:1 against a computed header
    /// luminance, with an `onBlue` escape hatch because a clear sky compresses the range so far
    /// that holding a ratio lands on grey. A two-colour system has no ratio to hold and no
    /// escape hatch to need: see `SkyField.mark`.
    private var titleColor: Color { markColour }

    /// The same black or white as the title. The caption used to be a step back in grey, and
    /// there are no greys now — the pair's order comes from 30pt against a footnote, which is
    /// what "size and weight, not colour" means in practice (Mason, 2026-10-09).
    private var captionColor: Color { markColour }


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
                return "\(Self.dayLine(model.focusDate, in: model.timeZone)) · \(start)"
            }
            let end = ArcContent.clock(active.endHour - offset)
            return "\(Self.dayLine(model.focusDate, in: model.timeZone)) · \(start) – \(end)"
        }
        return Self.dayLine(model.focusDate, in: model.timeZone)
    }

    // MARK: - Actions

    /// After an edit, not a scroll: resets the store first so a write is
    /// actually visible.
    private func reloadAfterEdit() {
        let range = model.loadedRange
        calendar.refreshSources()
        calendar.reloadAfterEdit(from: range.start, to: range.end, anchor: model.anchor)
        model.events = calendar.events
        publishSnapshot()
    }

    /// Hand the lock screen what it cannot work out for itself.
    ///
    /// The sun it can compute from a coordinate and a clock, so those go across
    /// as inputs. The next event it cannot: a widget has no event store unless
    /// it asks for calendar access of its own, and one permission prompt is
    /// enough for one app.
    /// Everything outside the arc is about NOW, never about where the arc has been dragged to.
    ///
    /// The events used to be whatever the arc had loaded — a day either side
    /// of the focus — so scrubbing three days out left the widgets with a
    /// snapshot that held no events for today at all. They come from the store
    /// now, for today and tomorrow, which is what a timeline running eight
    /// hours forward can reach.
    private func publishSnapshot() {
        let next = calendar.nearestTimedEvent(.forward, from: .now)
        let today = Calendar.current.startOfDay(for: .now)
        let events = calendar.timedOccurrences(
            from: today,
            to: today.addingTimeInterval(2 * 86_400)
        )

        SphereSnapshot.write(SphereSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timeZoneIdentifier: location.timeZone.identifier,
            placeName: location.placeName,
            nextEventTitle: next?.title,
            nextEventStart: next?.startDate,
            nextEventEnd: next?.endDate,
            events: events
        ))
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func reload() {
        let range = model.loadedRange
        calendar.refreshSources()
        calendar.load(from: range.start, to: range.end, anchor: model.anchor)
        model.events = calendar.events
        publishSnapshot()
    }

    /// Rebuilt rather than patched, on launch and on every calendar change. The schedule is a
    /// rolling week capped well under the only documented pending ceiling, so a tear-down costs
    /// nothing and a missed edit cannot accumulate.
    ///
    /// Not driven off `reload()` itself: `reload()` also runs when the focused day changes, which
    /// is a pan of the arc and has nothing to do with what is scheduled.
    private func rescheduleNotifications() async {
        await notifications.reschedule(using: calendar,
                                       coordinate: location.coordinate,
                                       timeZone: location.timeZone)
    }

    /// What is under the finger decides the action. Empty time creates AT THAT TIME rather than
    /// at the focus, which is the thing the wheel's centre button could not say. An event asks
    /// New or Open, because real days nest — a call inside a block, a break inside a shift — so
    /// landing on something must not be the end of putting something there (Mason, 2026-10-10;
    /// the same sheet the header button has shown since the wheel).
    /// All-day events are skipped — they have no hour to be tapped on.
    private func openAtTappedHour(_ hour: Double) {
        let start = snappedToFiveMinutes(hour)
        // If the header is showing an event, a tap can open it (Mason, 2026-10-14). The event
        // under the finger still wins when there is one; `model.activeEvent` is the fallback, and
        // it is exactly what the header draws, so the rule a reader can see on screen is the rule
        // the code runs: title in the header, Open on the card.
        //
        // Until today this asked only about the finger, and `contains` is exact while the capsule
        // is stroked with round caps that overhang each end by half a line width. So the visible
        // tips of an event missed, and so did the whole of it from inside either 44pt edge band,
        // where a tap is a step and never reaches this function. Mason saw it as Open appearing
        // on some parts of an event and not others.
        //
        // `start` is still the tapped time, not the active event's, so New event goes on creating
        // where the tap aimed. That is the whole reason the tap kept this sheet when Now left it.
        // Nested events: the one that STARTED most recently wins, which is the arc's rule for
        // overlap everywhere else and is why this calls `DayModel` rather than filtering here.
        // It read `model.events.first { ... }` until 2026-10-16, and the service sorts by start
        // ascending, so a call inside a three-hour block lost to the block.
        let underFinger = model.event(containing: hour)
        if let hit = underFinger ?? model.activeEvent,
           let occurrence = calendar.occurrence(for: hit.id) {
            choiceContext = ChoiceContext(event: occurrence, start: start)
            isEventChoiceOpen = true
        } else {
            // STUDY (Mason, 2026-10-10): a tap used to open the editor here, which was one
            // gesture to a new event. It asks first instead, so the tap costs a card for the
            // thing it used to do directly. On trial, and still unanswered through four
            // rearrangements. The pair it asks is New event or Pick date, both of which are
            // about the time under the finger; Now was the card that threw that time away and
            // has a corner button of its own as of 2026-10-16.
            timeChoiceStart = start
            isTimeChoiceOpen = true
        }
    }

    /// The raw tapped instant is something like 11:33:47, and EKEventEditViewController rounds
    /// that UP to the next five, so an event appeared several minutes after the spot that was
    /// tapped. Rounding to the NEAREST five here means the time the editor opens on is the time
    /// that was aimed at. Five is also finer than a fingertip: at the default window it is about
    /// 11 points, so the snap never takes the tap somewhere it was not pointing.
    private func snappedToFiveMinutes(_ hour: Double) -> Date {
        let step: TimeInterval = 5 * 60
        let raw = model.anchor.addingTimeInterval(hour * 3600).timeIntervalSince1970
        return Date(timeIntervalSince1970: (raw / step).rounded() * step)
    }

    /// What a choice means, in one place. The sheet calls it from `onDismiss` and the landscape
    /// panel calls it as it closes, so the two presentations can never answer differently.
    private func actOnTimeChoice() {
        guard let choice = pendingTimeChoice else { return }
        let start = timeChoiceStart ?? model.focusDate
        pendingTimeChoice = nil
        timeChoiceStart = nil
        switch choice {
        case .create:
            Sounds.ring(.editor)
            editorTarget = .new(start)
        case .pickDate:
            // The bell comes home (Mason, 2026-10-14). `.calendar` is `weather.m4a` and rang on
            // the wheel's CAL from 2026-09-12 — "Sound: weather rings on CAL", whose own message
            // also set "left / right -> silent". On 2026-10-10 `f456d51` moved the ring out of
            // the picker and into `step`, in a commit about the edge bands stepping events, and
            // the picker has been silent since. Restoring it rather than deleting the bell.
            Sounds.ring(.calendar)
            isDayPickerOpen = true
        }
    }

    /// The corner's pair. Both answers are sheets, so both wait for this one to be gone.
    private func actOnCornerChoice() {
        guard let choice = pendingCornerChoice else { return }
        pendingCornerChoice = nil
        switch choice {
        case .guide:
            // The guide has no bell of its own and never has. It is the only one of these
            // destinations that is a thing to read rather than a thing done.
            isGuideOpen = true
        case .menu:
            Sounds.ring(.menu)
            isMenuOpen = true
        }
    }

    /// Back to the present. ONE thing runs this now: `nowButton` in the bottom-leading corner.
    ///
    /// It has been the hold's first card, the time sheet's middle card, and a two-finger tap on
    /// the arc, in that order, and is none of them. The two-finger tap went on 2026-10-16
    /// (Mason), with its page in the guide: a corner button that states the distance and clears
    /// it on a press leaves a hidden shortcut to the same place with nothing left to offer, and
    /// a shortcut nobody is taught is a gesture that fires by accident and never on purpose.
    /// `TwoFingerTap.swift` went with it, 26 lines, its only caller being the line above.
    ///
    /// Already there is a no-op and not an arrival, so it rings nothing and shakes nothing. That
    /// guard was written for the two-finger tap, which was easy to land by accident while
    /// pinching, and it is kept for a smaller reason: the button is hidden inside the same
    /// one-minute window, so the only way to reach this while already on now is VoiceOver
    /// pressing a control it can still see.
    private func goToNow() {
        guard !model.isFocusedOnNow else { return }
        Haptics.warm()
        Sounds.ring(.now)
        travel { model.returnToNow() }
    }

    private func actOnEventChoice() {
        guard let choice = pendingChoice, let context = choiceContext else { return }
        pendingChoice = nil
        choiceContext = nil
        switch choice {
        case .open:
            Sounds.ring(.editor)
            editorTarget = .existing(context.event)
        case .create:
            Sounds.ring(.editor)
            editorTarget = .new(context.start)
        // The picker's own bell, as above, and the second of its two openings.
        case .pickDate:
            Sounds.ring(.calendar)
            isDayPickerOpen = true
        }
    }

    /// Asks for location on a launch where the onboarding will NOT, which is every launch after
    /// the first.
    ///
    /// The test is `.ready`, not "anything but `.new`". `.waiting` comes first and means the gate
    /// does not yet know, and reading it as "not new" raised the prompt on the very first launch
    /// a few milliseconds before the onboarding appeared — which is the thing this method exists
    /// to stop (2026-10-10). `.settling` and `.arrivedLate` are first-run states too; none of
    /// them is a launch that owes a prompt.
    ///
    /// Attached to `actOnTimeChoice` until 2026-10-13, which touches neither the gate nor the
    /// location.
    private func requestLocationIfPastOnboarding() {
        guard let gate, gate.hasResolved, gate.state == .ready else { return }
        guard location.access == .undetermined else { return }
        location.request()
    }

    /// Empty time just creates. On an event there are two things it could mean, so it asks
    /// rather than picking one: a day nests, and opening the outer event was the only thing on
    /// offer. The header title button's route into an event, and one of the two places the
    /// editor bell rings — `openAtTappedHour` is the other, which is the tap on the arc.
    ///
    /// The editor bell used to ring HERE, before the branch, on the argument that the choice
    /// sheet and the straight-to-new-event path are one press to the thumb and should sound the
    /// same. Mason overruled that on 2026-10-14: the bells mark functions, not modals, so a press
    /// that raises a question rings nothing and the bell waits for the editor. It now rings on the
    /// `else` below and inside `actOnEventChoice`, which means the same press does ring or not
    /// depending on what is under the dot — the thing the old arrangement existed to avoid, and
    /// the right answer anyway, because those two presses now do different things.
    ///
    /// This doc block spent some time attached to `openAtTappedHour`, one function above the one
    /// it describes, where it read as though that function were the header button's route. Moved
    /// 2026-10-13.
    private func openEditor() {
        if let event = model.activeEvent.flatMap({ calendar.occurrence(for: $0.id) }) {
            choiceContext = ChoiceContext(event: event, start: model.focusDate)
            isEventChoiceOpen = true
        } else {
            Sounds.ring(.editor)
            editorTarget = .new(model.focusDate)
        }
    }

    /// Move the focus to the next or previous event's START. Reached from the arc's left and
    /// right edge bands, which took this over from the chevrons on 2026-10-10.
    ///
    /// The near list only spans the drawn window, so when it comes up empty the
    /// store is asked over a much wider range before giving up. Without that,
    /// an event further out than a day was unreachable: the jump did nothing,
    /// the focus stayed put, and nothing triggered a reload to widen the view.
    /// Both callers want the same shrug, so it lives here rather than at the two call sites
    /// (2026-10-10, when the arc's edge bands adopted this).
    ///
    /// **Silent as of 2026-10-13.** Both branches rang `Sounds.ring(.calendar)` until Mason's
    /// call, and `Sounds`' own header had said all along that this control must not: the edge
    /// bands inherited the chevrons' job, and the chevrons were excluded by name because "a bell
    /// on a button you hit five times in a row is the definition of obnoxious". Stepping back
    /// through a busy afternoon stacked four or five strikes, each audible for about 4.5 seconds.
    /// The step is still reported twice without sound, by the warm-up below and by `travel`'s
    /// arrival haptic.
    private func step(_ direction: CalendarService.Direction) {
        if let near = direction == .forward ? model.nextEvent : model.previousEvent {
            Haptics.warm()
            travel { model.focusHour = near.startHour }
            return
        }
        guard let far = calendar.nearestTimedEvent(direction, from: model.focusDate) else {
            // Forty-five days out and still nothing. The dot cannot move, so
            // the only thing left to report is that there was nowhere to go.
            Haptics.nothingThere()
            return
        }
        Haptics.warm()
        travel { model.focusHour = far.startDate.timeIntervalSince(model.anchor) / 3600 }
    }

    /// One click per quarter hour of scrubbed time, counted against where the
    /// last click fired rather than against the rotation. Turning slowly and
    /// turning fast then click at the same places on the day, and a turn that
    /// crosses several at once still clicks once — a burst per frame would read
    /// as a buzz.
    private func clickPastDetents() {
        let step = Haptics.detentHours
        let crossed = (model.focusHour / step).rounded(.towardZero)
        guard crossed != lastDetent else { return }
        lastDetent = crossed
        Haptics.detentPassed()
    }

    /// Every way of moving the dot a long way at once goes through here.
    ///
    /// Moving the focus hour pans the whole arc, so every capsule crosses the
    /// screen on the way — which is most of what a long move looks like. They
    /// are all held back for the flight and revealed on arrival.
    ///
    /// Measured, when the duration was fixed and the distance was not: a one-hour hop travelled
    /// 130pt and an eight-hour one 1040pt, both in 0.55s, so the far end smeared at about
    /// 3000 pt/s against a readable 800 to 1200, and the capsule arriving mid-smear is what read
    /// as it being dragged along. (Those numbers sat on `step` until 2026-10-13, which is one of
    /// the four callers rather than the thing being described.)
    ///
    /// Critically damped, both on the pan and the reveal: a move should land,
    /// not settle. The reveal hangs off the animation's own completion rather
    /// than a timer; a timer is a guess at when a spring settles, and it goes
    /// stale the moment the spring is retuned.
    ///
    /// One function, because Now and an edge-band step do the same thing and the
    /// suppression was written at one call site and not the other. The arrival
    /// haptic lives here for the same reason: four call sites jump, and any of
    /// them written separately is the one that ends up silent.
    private func travel(_ change: () -> Void) {
        let origin = model.focusHour
        eventsHidden = true
        withAnimation(.spring(response: 0.5, dampingFraction: 1), completionCriteria: .removed) {
            change()
        } completion: {
            withAnimation(.easeOut(duration: 0.22)) { eventsHidden = false }
        }
        // Only when it actually went somewhere. Choosing Now while already on
        // now is a no-op, not an arrival, and reporting one would make the
        // app's haptic vocabulary mean less everywhere else.
        if model.focusHour != origin { Haptics.moved() }
    }

    /// Reload the sun and the sky for a place whose clock has arrived, which
    /// can happen after the coordinate does: a fix lands first and its timezone
    /// comes back from the geocoder a moment later.
    private func relocate() {
        model.relocate(to: location.coordinate, timeZone: location.timeZone)
        Task {
            await weather.load(coordinate: location.coordinate)
            model.applySky(from: weather)
        }
    }

    /// Formatted on the PLACE's clock, not the device's, so the date under the
    /// dot names the day the arc is drawing.
    private static func dayLine(_ date: Date, in zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        formatter.timeZone = zone
        return formatter.string(from: date)
    }

    /// Names the gesture, in the guide's own construction — every lesson there is "Tap to…",
    /// "Drag to…", "Hold for…". No full stop: the guide's lines are sentences in a paragraph and
    /// this one stands alone in the slot a readout usually fills, so it is a label.
    private static let nowHint = "Tap to return to now"

    /// Said permanently beside the distance, not only for the two seconds the hint lasts
    /// (Mason, 2026-10-20, after testing: "it's not obvious even with the on launch signifier").
    ///
    /// The hint was the lighter answer and it was not enough: it shows once per launch, it has to
    /// be caught, and a reader who looks at the corner on their second scrub of the session sees
    /// only a number. A number is a readout, and nothing about a readout says it can be pressed.
    ///
    /// Parenthesised and in Mason's own words. It rides on the same line as the distance rather
    /// than below it, so the control stays one line tall and the number keeps the sentence's
    /// stress.
    private static let tapBack = "(tap to go back to now)"

    /// How far the focus has travelled from the present, as a signed distance: "+4 hours",
    /// "−10 minutes", "+5 days", "+5 months".
    ///
    /// EXPERIMENT (Mason, 2026-10-16), standing in for the `.now` mark in the corner: "i think
    /// this icon isn't recognizable to users". A readout says what the icon could not, which is
    /// where you ARE, and it says what pressing does by implication, since the only thing that
    /// clears a distance is going back.
    ///
    /// The unit steps up when the ROUNDED value would overflow it: 59 minutes, then 1 hour; 23
    /// hours, then 1 day; 59 days, then 2 months. Rounding before the test rather than after is
    /// what makes that true, and the first draft of this did it the other way round, so 31
    /// minutes read "+1 hour" and nothing between 31 and 59 minutes could be said at all. The
    /// same inversion put "+24 hours" in the gap below one day.
    ///
    /// Months start at 2, which is why the day rung runs to 59 rather than to 30: a readout that
    /// stepped from "+30 days" to "+1 month" would drop in apparent size while the distance grew.
    ///
    /// All of it is arithmetic on the interval, including months at the Gregorian mean length.
    /// Calendar months were the first draft and they broke symmetry: the same magnitude read
    /// "+31 days" forward and "−1 month" back, because the two directions span different month
    /// pairs. This reads distance travelled along the arc rather than calendar boundaries
    /// crossed, which is also what the arc itself measures, so a scrub of 25 hours across
    /// midnight is "+1 day" rather than "+2 days".
    ///
    /// A true minus sign rather than a hyphen, which is the character that lines up with
    /// `monospacedDigit`.
    private static func distanceFromNow(_ focus: Date, from now: Date) -> String {
        let seconds = focus.timeIntervalSince(now)
        let sign = seconds < 0 ? "\u{2212}" : "+"

        func unit(_ value: Double, _ singular: String) -> String {
            "\(sign)\(Int(value)) \(singular)\(Int(value) == 1 ? "" : "s")"
        }

        /// Days in a mean Gregorian year over twelve.
        let meanMonth: Double = 30.436875

        let minutes = abs(seconds) / 60
        let roundedMinutes = minutes.rounded()
        if roundedMinutes < 60 { return unit(roundedMinutes, "minute") }

        let hours = (minutes / 60).rounded()
        if hours < 24 { return unit(hours, "hour") }

        let days = (minutes / 1440).rounded()
        if days < 60 { return unit(days, "day") }

        return unit((minutes / 1440 / meanMonth).rounded(), "month")
    }
}

#Preview {
    ContentView()
}
