import EventKit
import EventKitUI
import SwiftUI

/// What opening an event shows: Apple's detail view for anything that already
/// exists, and the editor only for something new.
///
/// Going straight to the editor claimed every event could be changed. An event
/// someone else created and invited you to refuses the write, so Save did
/// nothing and the sheet sat there — Calendar.app refuses it too, so the app was
/// the only thing implying otherwise. `EKEventViewController` decides for itself
/// whether to offer Edit, which covers read-only calendars, subscribed calendars
/// and invitations without us reproducing Apple's rule, and it carries RSVP.
///
/// This is the second time it has been built. The first (2026-09-01, 37a3cb8)
/// was reverted the same day (2ea8e89) because Edit PUSHED the editor, and
/// `EKEventEditViewController` is itself a `UINavigationController`, so two
/// Delete Event rows drew into one screen. Retested on device 2026-09-26: Edit
/// now presents the editor modally and the two screens are separate. If a future
/// OS pushes again, the symptom is those two Delete rows, and the fix is to set
/// `allowsEditing = false` and give the viewer our own Edit button that presents.
///
/// The cost is one extra tap to edit an event you own. Asked for, after using it.
enum EventTarget: Identifiable, Equatable {
    case new(Date)
    case newAllDay(Date)
    case existing(EKEvent)

    var id: String {
        switch self {
        case .new(let date): "new-\(date.timeIntervalSince1970)"
        case .newAllDay(let date): "newAllDay-\(date.timeIntervalSince1970)"
        case .existing(let event): "edit-\(event.eventIdentifier ?? "")-\(event.startDate.timeIntervalSince1970)"
        }
    }

    static func == (a: EventTarget, b: EventTarget) -> Bool { a.id == b.id }
}

/// An invisible host that PRESENTS the EventKit controllers itself rather than
/// being a SwiftUI sheet's content.
///
/// As sheet content, a controller dismisses itself as part of completing, and
/// inside a sheet that SwiftUI owns that dismissal goes nowhere and takes the
/// callback with it. Presented from a real view controller its own lifecycle
/// works, so saving and cancelling both report back.
///
/// Deleting never does, on any presentation: it commits to the store and skips
/// the delegate entirely. `closeIfEventDeleted` below is what covers it.
struct EventKitHost: UIViewControllerRepresentable {
    @Binding var target: EventTarget?
    let store: EKEventStore
    var defaultDuration: TimeInterval = 30 * 60
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let host = UIViewController()
        host.view.isUserInteractionEnabled = false
        return host
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.sync(host)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, EKEventEditViewDelegate, EKEventViewDelegate {
        var parent: EventKitHost

        /// What this host put on screen, so a sheet presented by anything else
        /// is never mistaken for ours.
        private weak var presented: UIViewController?
        private var isWaiting = false
        private var waitDeadline: Date?

        init(parent: EventKitHost) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged, object: nil, queue: .main
            ) { [weak self] _ in
                self?.closeIfEventDeleted()
            }
        }

        /// Brings what is on screen in line with `parent.target`.
        ///
        /// Opening an event from another sheet asks to present while that sheet
        /// is still on its way out, which UIKit refuses. SwiftUI does not call
        /// `updateUIViewController` again when it does, so bailing dropped the
        /// target until an unrelated re-render happened along — ten seconds, in
        /// the trace, and variable. Waiting for the presentation to clear is
        /// what makes an all-day event open at the tap.
        func sync(_ host: UIViewController) {
            guard let target = parent.target else {
                waitDeadline = nil
                if let presented, host.presentedViewController === presented {
                    host.dismiss(animated: true)
                }
                return
            }
            guard host.view.window != nil else { return }
            if let presented, host.presentedViewController === presented { return }

            guard host.presentedViewController == nil else {
                waitForPresentationToClear(host)
                return
            }

            waitDeadline = nil
            let controller: UIViewController = switch target {
            case .new(let start): editor(startingAt: start)
            case .newAllDay(let day): allDayEditor(on: day)
            // No editability check of our own. There used to be an `isEditable`
            // here — allowsContentModifications plus an organizer test — and it
            // went with the branch on 2026-09-26, because the detail view applies
            // Apple's rule and the rule has more cases in it than ours did.
            // Recover it from 2ea8e89 if this ever has to branch again.
            case .existing(let event): viewer(for: event)
            }
            presented = controller
            host.present(controller, animated: true)
        }

        /// A new event has nothing to view, so it opens straight in the editor.
        private func editor(startingAt start: Date) -> UIViewController {
            let event = EKEvent(eventStore: parent.store)
            event.startDate = start
            event.endDate = start.addingTimeInterval(parent.defaultDuration)
            event.calendar = parent.store.defaultCalendarForNewEvents
            return editor(for: event)
        }

        /// One whole day, so start and end land on the same date: that is what
        /// Calendar.app writes for a single all-day event, and what the editor
        /// reads back as one day rather than two.
        private func allDayEditor(on day: Date) -> UIViewController {
            let event = EKEvent(eventStore: parent.store)
            let start = Calendar.current.startOfDay(for: day)
            event.isAllDay = true
            event.startDate = start
            event.endDate = start
            event.calendar = parent.store.defaultCalendarForNewEvents
            return editor(for: event)
        }

        private func editor(for event: EKEvent) -> UIViewController {
            let controller = EKEventEditViewController()
            controller.eventStore = parent.store
            controller.editViewDelegate = self
            controller.event = event
            return controller
        }

        /// Every existing event, shown the way Calendar.app shows it: the
        /// details, Edit when EventKit will accept a write, and RSVP when the
        /// event is an invitation.
        ///
        /// `EKEventViewController` needs a navigation controller for its bar,
        /// and presented modally it offers no way out, so Done goes there. The
        /// bar is otherwise Apple's: Edit is the controller's own, on the
        /// trailing edge, and appears or not by its rule rather than ours. The
        /// LEADING button is the only thing here we draw — Calendar.app puts a
        /// close glyph there, which is `.close` rather than `.done` if this ever
        /// wants to match it exactly.
        private func viewer(for event: EKEvent) -> UIViewController {
            let controller = EKEventViewController()
            controller.event = event
            controller.delegate = self
            controller.allowsEditing = true
            controller.allowsCalendarPreview = true
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done, target: self, action: #selector(finish)
            )
            return UINavigationController(rootViewController: controller)
        }

        /// Bounded, so a presentation that never clears cannot spin forever.
        private func waitForPresentationToClear(_ host: UIViewController) {
            if waitDeadline == nil { waitDeadline = Date().addingTimeInterval(2) }
            guard let deadline = waitDeadline, Date() < deadline else {
                waitDeadline = nil
                return
            }
            guard !isWaiting else { return }
            isWaiting = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak host] in
                guard let self else { return }
                self.isWaiting = false
                guard let host else { return }
                self.sync(host)
            }
        }

        /// Deleting commits to the store and never calls the edit delegate —
        /// saving and cancelling both do. So the editor sat open over an event
        /// that was already gone, and nothing reloaded until the next launch.
        /// The store's own change notification is the only signal it happened.
        private func closeIfEventDeleted() {
            guard case .existing(let event)? = parent.target else { return }
            guard !Self.occurrenceStillExists(event, in: parent.store) else { return }
            finish()
        }

        /// Whether the exact occurrence on screen is still in the store.
        ///
        /// Asking by identifier is not enough: every occurrence of a recurring
        /// event shares the series' identifier, so after "delete all future
        /// events" the series is still there, truncated, and the identifier
        /// still resolves. The editor sat open over an occurrence that was gone
        /// and its Cancel had nothing left to cancel. Same hole for "this event
        /// only" on any occurrence but the first. So the check is for an event
        /// with this identifier starting at this moment, in this window.
        static func occurrenceStillExists(_ event: EKEvent, in store: EKEventStore) -> Bool {
            guard let identifier = event.eventIdentifier else { return true }
            guard store.event(withIdentifier: identifier) != nil else { return false }
            let start = event.startDate ?? Date()
            let end = max(event.endDate ?? start, start.addingTimeInterval(1))
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
            return store.events(matching: predicate).contains {
                $0.eventIdentifier == identifier && $0.startDate == start
            }
        }

        /// Editing inside the detail view reports back to that view, not to us,
        /// so every way out reloads rather than trusting nothing changed.
        @objc private func finish() {
            parent.target = nil
            parent.onFinish()
        }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true) { [weak self] in self?.finish() }
        }

        func eventViewController(_ controller: EKEventViewController,
                                 didCompleteWith action: EKEventViewAction) {
            finish()
        }
    }
}
