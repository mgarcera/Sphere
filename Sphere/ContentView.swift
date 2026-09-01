import EventKit
import SwiftUI

struct ContentView: View {
    @State private var model = DayModel()
    @State private var calendar = CalendarService()
    @State private var location = LocationService()
    @State private var weather = WeatherService()
    @State private var editorTarget: EventTarget?
    @State private var isMenuOpen = false
    /// Temporary: two cloud constructions under comparison. This and the
    /// loser come out together.
    @AppStorage("skyShape") private var skyShape: SkyShape = .lobed

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            TwilightBackground(
                elevationDegrees: model.elevationDegrees(atAbsoluteHour: model.focusHour),
                isMorning: model.focusHour - Double(model.dayIndex) * 24 < model.focusSolarDay.solarNoon
            )

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
        .sheet(item: $editorTarget) { target in
            EventEditorSheet(store: calendar.store, target: target) {
                editorTarget = nil
                Task { @MainActor in reload() }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isMenuOpen) {
            DayMenu(model: model, calendar: calendar, location: location, skyShape: $skyShape) { isMenuOpen = false }
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

            ArcWindow(model: model, skyShape: skyShape)
                .padding(.top, 40)

            Spacer(minLength: 16)

            ClickWheel(
                onRotate: { model.scrub(byRotations: $0) },
                onMenu: { isMenuOpen = true },
                onNow: { springTo { model.returnToNow() } },
                onCentre: openEditor,
                onPrevious: { springTo { model.jumpToPreviousEvent() } },
                onNext: { springTo { model.jumpToNextEvent() } }
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
                    .foregroundStyle(Theme.ink)
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
                .foregroundStyle(Theme.muted)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var hourOfDay: Double {
        model.focusHour - Double(model.dayIndex) * 24
    }

    /// Carries the day change, since the arc itself deliberately doesn't.
    private var subtitle: String {
        if let active = model.activeEvent {
            return "\(ArcContent.clock(active.startHour - Double(model.dayIndex) * 24)) · \(Self.dayLine(model.focusDate))"
        }
        return model.isFocusedOnToday ? Self.dayLine(model.focusDate)
                                      : "\(Self.dayLine(model.focusDate)) · \(ArcContent.clock(hourOfDay))"
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
