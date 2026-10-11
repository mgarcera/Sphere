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
    /// Where a Create from that sheet starts. A tap fills it with the time under the finger; a
    /// hold has no location to give, so it fills it with the focus.
    @State private var timeChoiceStart: Date?
    @State private var pickedDay: Date = .now
    /// Which side of the horizon the Sky mode is on.
    ///
    /// Held in state rather than read from `typeNight` so the flip can be made
    /// with animations explicitly off. The wheel scrubs through sunset inside
    /// an animated transaction, and everything in a transaction animates
    /// whether or not you asked — a palette crossfade is precisely what this
    /// mode exists not to do.
    @State private var skyIsNight = false
    /// Shown once, when the onboarding hands over. The question mark in the corner replays it.
    @AppStorage("teachGhostSeen") private var guideSeen = false
    @State private var isGuideOpen = false

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
                // Two screens, each immediately before the thing it explains. The screen this
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

            // Invisible, and behind everything: it only exists to present the
            // EventKit controllers from a real view controller.
            EventKitHost(target: $editorTarget, store: calendar.store) {
                reloadAfterEdit()
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.25), value: calendar.access)
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
            .presentationDetents([.height(420)])
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
                .presentationDetents([.height(GestureGuide.height)])
                // Hidden, like the other two (Mason, 2026-10-10). It was shown for one build on
                // the argument that a sheet which is read rather than answered owes a visible
                // way out; a grabber over a page of hands is one more mark competing with the
                // six being demonstrated, and a sheet drags down whether or not it says so.
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isTimeChoiceOpen, onDismiss: {
            guard let choice = pendingTimeChoice else { return }
            let start = timeChoiceStart ?? model.focusDate
            pendingTimeChoice = nil
            timeChoiceStart = nil
            switch choice {
            case .now:
                guard !model.isFocusedOnNow else { return }
                Haptics.warm()
                Sounds.ring(.now)
                travel { model.returnToNow() }
            case .create:
                editorTarget = .new(start)
            case .pickDate:
                isDayPickerOpen = true
            }
        }) {
            TimeChoiceSheet { choice in
                pendingTimeChoice = choice
                isTimeChoiceOpen = false
            }
            .presentationDetents([.height(TimeChoiceSheet.height)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isEventChoiceOpen, onDismiss: {
            guard let choice = pendingChoice, let context = choiceContext else { return }
            pendingChoice = nil
            choiceContext = nil
            switch choice {
            case .open: editorTarget = .existing(context.event)
            case .create: editorTarget = .new(context.start)
            case .pickDate: isDayPickerOpen = true
            }
        }) {
            EventChoiceSheet { choice in
                pendingChoice = choice
                isEventChoiceOpen = false
            }
            .presentationDetents([.height(EventChoiceSheet.height)])
            .presentationDragIndicator(.hidden)
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
            if proxy.size.width > proxy.size.height {
                landscapeDay(width: proxy.size.width)
            } else {
                portraitDay
            }
        }
    }

    /// The header takes a column and stops competing for height. Nothing is scaled down and
    /// nothing is clipped: the same arc, the same header, side by side.
    private func landscapeDay(width: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            header
                .frame(width: Self.headerColumn(in: width), alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 12)

            arcBlock
                .modifier(ScrubAffordance(mark: markColour))
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottomLeading) { guideButton }
    }

    /// Wide enough for the longest line the header sets — the date, about 130 points — with room
    /// for an event title to wrap once, and never more than a third of the screen, because what
    /// is left is what the arc has to draw a day in.
    private static func headerColumn(in width: CGFloat) -> CGFloat {
        min(300, max(220, width * 0.32))
    }

    private var portraitDay: some View {
        // One arrangement at every size (Mason, 2026-10-09: an overlay is fine in landscape).
        // The arc centres in the WHOLE space and the header sits over it, rather than above it
        // in the flow — in the flow, the header's height was subtracted from the space the arc
        // centred in, so gaining an all-day event grew the header and pushed the arc down by
        // half that growth. The drawing moved because a list did.
        arcBlock
            // The arc's content fades at both edges, which is true — there IS more day that
            // way — and is the one signifier a horizontally scrolling surface has.
            .modifier(ScrubAffordance(mark: markColour))
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
            // Deliberately dim, and the one exception to "no greys": its whole job is to be
            // ignorable until someone is looking for it. The day menu carried this for one
            // build and nobody opens a menu row until they are already stuck.
            .overlay(alignment: .bottomLeading) { guideButton }
    }

    /// Deliberately dim, and the one exception to "no greys": its whole job is to be ignorable
    /// until someone is looking for it. The day menu carried this for one build and nobody opens
    /// a menu row until they are already stuck.
    private var guideButton: some View {
        Button {
            isGuideOpen = true
        } label: {
            Image(systemName: "questionmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(markColour.opacity(0.3))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
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
                      // STUDY: the same two callbacks the wheel reports through, so the drag and
                      // the rotation land on one code path and feel identical past the touch.
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
                      // Back to the menu (Mason, 2026-10-10, same day it left). Holding had the
                      // time sheet for one build, and the single tap took that over: a tap
                      // carries the time the sheet needs and the hold does not, so the hold was
                      // the worse way in to the same three cards. The menu is what is left that
                      // needs no aim.
                      onHold: {
                          Sounds.ring(.menu)
                          isMenuOpen = true
                      },
                      onTwoFingerTap: {
                          Sounds.ring(.menu)
                          isMenuOpen = true
                      },
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
        // opposite premise — that the wheel turning through sunset under a
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
    /// **Only the system's furniture turns.** The app's own type stays dark and
    /// lets `ContrastHold` drive it against the blue, which is both the chosen
    /// look and the more legible one: on that ground black measures about 4.8:1
    /// against white's 3.1:1. The status bar cannot be given a colour, only a
    /// scheme, so it gets the one that reads on the deepest part of the
    /// gradient — which is where it happens to sit.
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
    private var showsNightSky: Bool { effectiveScheme == .dark }

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

    /// What the sky is doing at the hour the wheel is on: the mark, the word
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

    /// How dark the sky is at the hour the wheel is on.
    private var nightness: Double {
        guard showsNightSky else { return 0 }
        return SkyDepth.nightness(elevationDegrees: model.elevationDegrees(atAbsoluteHour: model.focusHour))
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


    private var isMorning: Bool {
        model.focusHour - Double(model.dayIndex) * 24 < model.focusSolarDay.solarNoon
    }


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
    /// Everything outside the arc is about NOW, never about the wheel.
    ///
    /// The events used to be whatever the wheel had loaded — a day either side
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

    /// Empty time just creates. On an event there are two things it could mean, so it asks
    /// rather than picking one: a day nests, and opening the outer event was the only thing on
    /// offer. The header title button's route into an event, and one of the two places the
    /// editor bell rings — `openAtTappedHour` above is the other, which is the tap on the arc.
    ///
    /// It sits here rather than on the event actually being created, so the two
    /// branches sound the same: the choice sheet and the straight-to-new-event
    /// path are one press to the thumb, and only this level knows that. Ringing
    /// deeper meant the same press rang or not depending on whether something
    /// happened to be under the dot.
    /// What is under the finger decides the action. Empty time creates AT THAT TIME rather than
    /// at the focus, which is the thing the wheel's centre button could not say. An event asks
    /// New or Open, because real days nest — a call inside a block, a break inside a shift — so
    /// landing on something must not be the end of putting something there (Mason, 2026-10-10;
    /// the same sheet the header button has shown since the wheel).
    /// All-day events are skipped — they have no hour to be tapped on.
    private func openAtTappedHour(_ hour: Double) {
        Sounds.ring(.editor)
        let start = snappedToFiveMinutes(hour)
        let hit = model.events.first { !$0.isAllDay && $0.contains(hour) }
        if let hit, let occurrence = calendar.occurrence(for: hit.id) {
            choiceContext = ChoiceContext(event: occurrence, start: start)
            isEventChoiceOpen = true
        } else {
            // STUDY (Mason, 2026-10-10): a tap used to open the editor here, which was one
            // gesture to a new event. It now asks the same three things the hold asks, so the
            // tap costs a card for the thing it used to do directly. On trial.
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

    /// Asks for location on a launch where the onboarding will NOT, which is every launch after
    /// the first.
    ///
    /// The test is `.ready`, not "anything but `.new`". `.waiting` comes first and means the gate
    /// does not yet know, and reading it as "not new" raised the prompt on the very first launch
    /// a few milliseconds before the onboarding appeared — which is the thing this method exists
    /// to stop (2026-10-10). `.settling` and `.arrivedLate` are first-run states too; none of
    /// them is a launch that owes a prompt.
    private func requestLocationIfPastOnboarding() {
        guard let gate, gate.hasResolved, gate.state == .ready else { return }
        guard location.access == .undetermined else { return }
        location.request()
    }

    private func openEditor() {
        Sounds.ring(.editor)
        if let event = model.activeEvent.flatMap({ calendar.occurrence(for: $0.id) }) {
            choiceContext = ChoiceContext(event: event, start: model.focusDate)
            isEventChoiceOpen = true
        } else {
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
    /// Both callers want the same bell and the same shrug, so both live here rather than at the
    /// two call sites (2026-10-10, when the arc's edge bands adopted this).
    private func step(_ direction: CalendarService.Direction) {
        if let near = direction == .forward ? model.nextEvent : model.previousEvent {
            Haptics.warm()
            Sounds.ring(.calendar)
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
        Sounds.ring(.calendar)
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
    /// Critically damped, both on the pan and the reveal: a move should land,
    /// not settle. The reveal hangs off the animation's own completion rather
    /// than a timer; a timer is a guess at when a spring settles, and it goes
    /// stale the moment the spring is retuned.
    ///
    /// One function, because NOW and the chevrons do the same thing and the
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
        // Only when it actually went somewhere. Pressing NOW while already on
        // now is a no-op, not an arrival, and reporting one would make the
        // wheel's vocabulary mean less everywhere else.
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
}

#Preview {
    ContentView()
}
