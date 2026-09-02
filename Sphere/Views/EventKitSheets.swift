import EventKit
import EventKitUI
import SwiftUI

/// What opening an event shows: the editor for anything you can change, and
/// Apple's read-only detail view for anything you cannot.
///
/// Going straight to the editor for everything claimed every event could be
/// changed. An event someone else created and invited you to refuses the write,
/// so Save did nothing and the sheet sat there — Calendar.app refuses it too,
/// so the app was the only thing implying otherwise.
///
/// Routing everything through the detail view instead cost a tap on your own
/// events and nested `EKEventEditViewController`, which is itself a
/// `UINavigationController`, inside another one: Edit pushed rather than
/// presented, and the two screens drew a Delete Event row each into the same
/// one. Branching keeps both flows Apple's own and unnested.
enum EventTarget: Identifiable, Equatable {
    case new(Date)
    case existing(EKEvent)

    var id: String {
        switch self {
        case .new(let date): "new-\(date.timeIntervalSince1970)"
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
            case .existing(let event): Self.isEditable(event) ? editor(for: event) : viewer(for: event)
            }
            presented = controller
            host.present(controller, animated: true)
        }

        /// Whether EventKit will accept a write to this event.
        ///
        /// An editable calendar is not enough on its own: an invitation sits on
        /// your own writable calendar and still cannot be changed, which is why
        /// Save appeared to do nothing. An event you created has no organizer
        /// at all; one you were invited to names someone who is not you.
        static func isEditable(_ event: EKEvent) -> Bool {
            guard event.calendar?.allowsContentModifications == true else { return false }
            guard let organizer = event.organizer else { return true }
            return organizer.isCurrentUser
        }

        /// A new event has nothing to view, so it opens straight in the editor.
        private func editor(startingAt start: Date) -> UIViewController {
            let event = EKEvent(eventStore: parent.store)
            event.startDate = start
            event.endDate = start.addingTimeInterval(parent.defaultDuration)
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

        /// The read-only half: an event you cannot change, shown the way
        /// Calendar.app shows it, with the RSVP controls that are the only
        /// thing you can actually do with an invitation.
        ///
        /// `EKEventViewController` needs a navigation controller for its bar,
        /// and presented modally it offers no way out, so Done goes there.
        /// Editing stays off — this path is only reached when EventKit would
        /// refuse the write anyway, and leaving it on nested the editor's own
        /// navigation controller inside this one.
        private func viewer(for event: EKEvent) -> UIViewController {
            let controller = EKEventViewController()
            controller.event = event
            controller.delegate = self
            controller.allowsEditing = false
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
            guard case .existing(let event)? = parent.target,
                  let identifier = event.eventIdentifier,
                  parent.store.event(withIdentifier: identifier) == nil
            else { return }
            finish()
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
