import EventKit
import SmidgecraftKit
import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var model = DayModel()
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
    /// Which quarter-hour the wheel last clicked at, so a click fires on
    /// crossing rather than on every frame of the drag.
    @State private var lastDetent: Double = 0
    @State private var allDayScale: CGFloat = 1
    /// Mirrors model.allDayEvents.count. The branch below reads THIS, not the
    /// model, so the row's appearance and disappearance always happen inside
    /// a transaction we control.
    @State private var allDayCount = 0
    @AppStorage("appearance") private var appearance: Appearance = .sky
    /// Observed rather than read once: the bottom button's printed word changes
    /// with it, and a label that does not follow its setting is worse than no
    /// setting at all.
    @AppStorage(WheelMapping.bottomKey) private var bottomPrimary: WheelAction = .now
    @AppStorage(Haptics.key) private var hapticsEnabled = true
    @State private var eventsHidden = false
    @State private var isAllDayOpen = false
    @State private var isDayPickerOpen = false
    @State private var isEventChoiceOpen = false
    @State private var showsWheelTip = false
    /// One claim per launch, whichever route gets there first: the tip is gated on calendar
    /// access being settled, and that settles either before this view appears or after the
    /// first-run flow, never both.
    @State private var didClaimWheelTip = false
    /// Acted on after the chooser closes, never while it is closing: presenting
    /// the editor into a sheet still dismissing is the refusal that cost ten
    /// seconds once already.
    @State private var pendingChoice: EventChoice?
    @State private var pickedDay: Date = .now
    /// Which side of the horizon the Sky mode is on.
    ///
    /// Held in state rather than read from `typeNight` so the flip can be made
    /// with animations explicitly off. The wheel scrubs through sunset inside
    /// an animated transaction, and everything in a transaction animates
    /// whether or not you asked — a palette crossfade is precisely what this
    /// mode exists not to do.
    @State private var skyIsNight = false

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

            if let gate, gate.hasResolved, gate.state == .new {
                // Two screens, each immediately before the thing it explains. The screen this
                // replaced explained both permissions and then raised both prompts back to back,
                // so the location one arrived with its reason two screens of attention earlier
                // (2026-10-04).
                FirstRunFlow(calendar: calendar, location: location) {
                    gate.markOnboardingComplete()
                    reload()
                }
                .transition(.opacity)
            } else {
                day
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
        .task { considerWheelTip() }
        .onChange(of: calendar.access) { _, _ in considerWheelTip() }
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
        .sheet(isPresented: $isEventChoiceOpen, onDismiss: {
            guard let choice = pendingChoice else { return }
            pendingChoice = nil
            switch choice {
            case .open:
                if let active = model.activeEvent,
                   let event = calendar.occurrence(for: active.id) {
                    editorTarget = .existing(event)
                }
            case .create:
                editorTarget = .new(model.focusDate)
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
            if location.access == .undetermined { location.request() }
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
    }

    private var day: some View {
        // `showsWheelTip` and its machinery are still live below but nothing renders them now:
        // the tip's overlay lived on the wheel. Kept rather than deleted because the gesture set
        // replacing the wheel has the same problem the tip was built for — a hold, and now a
        // drag, that nothing on screen admits exists — so this is the teacher it will reuse.
        VStack(spacing: 0) {
            // Centred rather than top-anchored (Mason, 2026-10-09). The wheel used to hold the
            // bottom ~475 points; with it gone the block was pinned to the top of the screen and
            // all the vacancy pooled under the hour labels. A Spacer either side splits it.
            Spacer(minLength: 0)
            arcBlock
            Spacer(minLength: 0)
        }
        .padding(.vertical, 24)
        // PROVISIONAL (2026-10-09): the wheel is gone and MENU went with it, which took the only
        // route to settings, calendars and feedback. This button exists so the app is not
        // stranded while the abstract layer is designed. It is placed, not designed.
        .overlay(alignment: .bottomTrailing) {
            Button {
                Sounds.ring(.menu)
                isMenuOpen = true
            } label: {
                Text("MENU")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(markColour)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 16)
        }
    }

    private var arcBlock: some View {
        VStack(spacing: 0) {
            // Above the arc block, not below it. The night is drawn inside the
            // block and reaches up over this whole area, and a later sibling in
            // a stack draws on top — so without this the type is behind the sky
            // rather than on it, whatever colour it is.
            header
                // 12 lower than it sat. The arc follows, since the header sets its start.
                .padding(.top, 12)
                .zIndex(1)

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
                      // STUDY: hold to return to now. Same landing the wheel's NOW button used,
                      // so the jump animates identically and only the way in has changed.
                      onHold: {
                          guard !model.isFocusedOnNow else { return }
                          Haptics.warm()
                          Sounds.ring(.now)
                          travel { model.returnToNow() }
                      })
                .padding(.top, 8)
                // The weather line, drawn into the arc box's sky gutter — the 100pt of room
                // above the curve's ceiling that exists so tall clouds are not clipped. On a
                // low deck this is the empty band that used to sit between the header and the
                // clouds; the line lives there now, an overlay, so it costs the column nothing.
                .overlay(alignment: .topLeading) {
                    weatherLine
                        .padding(.top, weatherOffset)
                        .padding(.leading, 24)
                        // One property, moved on the same spring the all-day row pops with,
                        // so crossing onto a birthday reads as the line making room.
                        .animation(Self.popSpring, value: allDayCount)
                }
        }
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
            // event — which is most of the day. On paper `ContrastHold` already
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

            // The weather's SLOT, kept empty. The line itself is drawn lower, over the arc's
            // sky gutter (see `ArcWindow` below), because the clouds sit ~100pt beneath the
            // header's last line and closing the header's own gap could never reach them.
            // The slot stays so the header keeps its height and nothing else moves.
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

    /// Where the weather line sits, from the arc box's top edge, by how many all-day rows
    /// there are to make room for. It fills the band between the date and the clouds:
    ///
    /// Always directly BELOW the all-day block, however tall it is.
    ///
    /// Measured from the arc box's top edge. The block's top is 67 ABOVE the box: the arc's
    /// 8pt top pad, the weather's empty 23pt slot in the header, and the 36pt two-line
    /// reservation. Negative padding on an overlay draws there. Below that, the block is a
    /// footnote line for the count plus one per event, 4 apart; the weather sits 4 under
    /// the last of them. With no events it sits under the date.
    ///
    /// One formula rather than positions per count: an earlier version parked the line on
    /// the cloud tops from two events up, and the jump from one event to two was 63pt —
    /// "it goes really far". Following the block keeps every step the same 20.
    private var weatherOffset: CGFloat {
        let line: CGFloat = 16, gap: CGFloat = 4, blockTop: CGFloat = -67
        guard allDayCount > 0 else { return blockTop }
        let block = line + CGFloat(allDayCount) * (gap + line)
        return blockTop + block + gap
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

    /// How much blue is on the screen right now, 0 to `ClearBlue.peakOpacity`.
    private var blueStrength: Double {
        ClearBlue.strength(clearness: model.clearness(atAbsoluteHour: model.focusHour),
                           elevationDegrees: focusElevation,
                           suppressedBy: washAmount / WeatherWash.stormPeak)
            * ClearBlue.peakOpacity
    }

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
    private var onBlue: Bool { blueStrength > 0.55 }

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
    /// It follows the wheel like the rest of the header — the arc's clouds are
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

    /// Held against the ground by day, and taken over by the sky at night.
    ///
    /// The hold both raises and CAPS, which is what it is for — the title comes
    /// down to its target on a clear day so the caption cannot catch it. On a
    /// night sky the cap is the wrong instinct: it lifts the ink to nine to one
    /// and stops there, which is a light grey. Above the horizon the header is
    /// sky, so it ends on the sky's own ink like every other mark up there.
    /// When the header's type turns over: at the horizon, across two degrees,
    /// which is a few minutes either side of sunset.
    ///
    /// NOT on the sky's own schedule. The sky keeps darkening for another
    /// twelve degrees after that, and waiting for it left the type dark on a
    /// dimming ground for the best part of an hour. The contrast arithmetic
    /// agreed with the wait — at a ground of 0.25 a dark ink scores 6:1 against
    /// white's 3.5:1, so the hold kept choosing dark — and it was wrong: by
    /// then the screen reads as evening and evening type is light.
    private var typeNight: Double {
        showsNightSky ? nightTurn : 0
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
            twilight: (TwilightBackground.lightTopColor(isMorning: isMorning), twilight),
            night: (TwilightBackground.nightTopComponents,
                    showsNightSky
                        ? TwilightBackground.nightOpacity(
                            elevationDegrees: elevation,
                            suppressedBy: washAmount / WeatherWash.stormPeak)
                        : 0),
            blue: (ClearBlue.topComponents, blueStrength)
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

    /// In empty time the centre button just creates. Inside an event there are
    /// two things it could mean, so it asks rather than picking one: a day
    /// nests, and opening the outer event was the only thing on offer.
    /// The centre press, and the one place the editor bell rings.
    ///
    /// It sits here rather than on the event actually being created, so the two
    /// branches sound the same: the choice sheet and the straight-to-new-event
    /// path are one press to the thumb, and only this level knows that. Ringing
    /// deeper meant the same press rang or not depending on whether something
    /// happened to be under the dot.
    /// STUDY (2026-10-09): what is under the finger decides the action. An event opens; empty
    /// time creates AT THAT TIME rather than at the focus, which is the thing the wheel's centre
    /// button could not say. All-day events are skipped — they have no hour to be tapped on.
    private func openAtTappedHour(_ hour: Double) {
        Sounds.ring(.editor)
        let hit = model.events.first { !$0.isAllDay && $0.contains(hour) }
        if let hit, let occurrence = calendar.occurrence(for: hit.id) {
            editorTarget = .existing(occurrence)
        } else {
            editorTarget = .new(model.anchor.addingTimeInterval(hour * 3600))
        }
    }

    private func openEditor() {
        Sounds.ring(.editor)
        if model.activeEvent.flatMap({ calendar.occurrence(for: $0.id) }) != nil {
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
    private func step(_ direction: CalendarService.Direction) {
        if let near = direction == .forward ? model.nextEvent : model.previousEvent {
            travel { model.focusHour = near.startHour }
            return
        }
        guard let far = calendar.nearestTimedEvent(direction, from: model.focusDate) else {
            // Forty-five days out and still nothing. The dot cannot move, so
            // the only thing left to report is that there was nowhere to go.
            Haptics.nothingThere()
            return
        }
        travel { model.focusHour = far.startDate.timeIntervalSince(model.anchor) / 3600 }
    }

    /// Everything the wheel does, in one place.
    ///
    /// Taps are the wheel's vocabulary and are fixed, except at the bottom,
    /// where the printed word changes with the setting. Holds are assignable,
    /// which is only safe because nothing is printed for them: a label that
    /// could come to mean something else stops being readable.
    /// Show the wheel tip, if it still has a showing left and there is a wheel to point at.
    ///
    /// Gated on access being settled rather than granted: a denied calendar still leaves the
    /// wheel on screen and every hold still works. Undetermined is the one state with no wheel
    /// in it — `FirstRunFlow` covers the screen — and a tip over a permission prompt is two
    /// asks at once.
    private func considerWheelTip() {
        guard !didClaimWheelTip, calendar.access != .undetermined else { return }
        didClaimWheelTip = true
        guard WheelTipState.claimLaunch() else { return }
        withAnimation(.snappy.delay(0.6)) { showsWheelTip = true }
    }

    private func press(_ position: WheelPosition, _ gesture: WheelGesture) {
        guard gesture == .tap else {
            // Any hold, anywhere on the wheel, is the tip's job done. It teaches that holds
            // exist, so the first one proves the message landed — including one found without it.
            WheelTipState.retire()
            withAnimation(.snappy) { showsWheelTip = false }
            return run(WheelMapping.hold(for: position))
        }
        switch position {
        case .previous: step(.back)
        case .next: step(.forward)
        case .menu: Sounds.ring(.menu); isMenuOpen = true
        case .centre: openEditor()
        case .bottom: run(WheelMapping.bottomPrimary)
        }
    }

    private func run(_ action: WheelAction) {
        switch action {
        case .none: break
        case .now: Sounds.ring(.now); travel { model.returnToNow() }
        case .calendar:
            Sounds.ring(.calendar)
            pickedDay = model.focusDate
            isDayPickerOpen = true
        // The same clock time a day either side, which is what makes this
        // different from the chevrons' tap: those land on an event, this lands
        // on where you already were.
        case .previousDay: travel { model.focusHour -= 24 }
        case .nextDay: travel { model.focusHour += 24 }
        case .newAllDay: editorTarget = .newAllDay(model.focusDate)
        case .appearance: flipAppearance()
        case .openCalendarApp: openCalendarApp()
        case .muteHaptics: hapticsEnabled.toggle()
        }
    }

    /// With two settings there is nothing to be clever about: it swaps them.
    ///
    /// It used to land on the opposite of what was ON SCREEN, which mattered
    /// when a third option could be showing either. Natural Sky at night and
    /// Dark look the same, so "opposite of what is showing" would have made the
    /// toggle a no-op after sunset.
    private func flipAppearance() {
        withAnimation(.easeInOut(duration: 0.25)) {
            appearance = appearance == .dark ? .sky : .dark
        }
    }

    /// `calshow:` takes seconds since the 2001 reference date, so Calendar
    /// opens on the day being looked at rather than on today.
    private func openCalendarApp() {
        let seconds = model.focusDate.timeIntervalSinceReferenceDate
        guard let url = URL(string: "calshow:\(seconds)") else { return }
        UIApplication.shared.open(url)
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
