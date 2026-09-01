import EventKit
import SwiftUI

struct ContentView: View {
    @State private var model = DayModel()
    @State private var calendar = CalendarService()
    @State private var editorStart: Date?
    @State private var detailEvent: EKEvent?
    @State private var isMenuOpen = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if calendar.access == .undetermined {
                CalendarPriming {
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
        .sheet(item: $editorStart) { start in
            EventEditorSheet(store: calendar.store, start: start) {
                editorStart = nil
                reload()
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isMenuOpen) {
            DayMenu(model: model, calendar: calendar) { isMenuOpen = false }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $detailEvent) { event in
            EventDetailSheet(event: event) {
                detailEvent = nil
                reload()
            }
            .ignoresSafeArea()
        }
        .task {
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
        .onChange(of: model.dayIndex) { _, _ in reload() }
        .onChange(of: calendar.hiddenSourceIDs) { _, _ in reload() }
    }

    private var day: some View {
        VStack(spacing: 0) {
            header

            ArcWindow(model: model)
                .padding(.top, 40)

            Spacer(minLength: 16)

            ClickWheel(
                onRotate: { model.scrub(byRotations: $0) },
                onMenu: { isMenuOpen = true },
                onCentre: { editorStart = model.focusDate },
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
                openActiveEvent()
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

    private func openActiveEvent() {
        guard let active = model.activeEvent,
              let event = calendar.event(withIdentifier: active.eventIdentifier) else { return }
        detailEvent = event
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

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}

extension EKEvent: @retroactive Identifiable {}

#Preview {
    ContentView()
}
