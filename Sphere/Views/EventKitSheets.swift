import EventKit
import EventKitUI
import SwiftUI

/// What opening an event shows: Apple's own detail view for one that already
/// exists, and the editor for one being created.
///
/// The detail view is what Calendar.app shows, and it decides for itself
/// whether Edit is offered — an event on a subscribed or read-only calendar, or
/// one you were invited to rather than created, has no Edit button. Going
/// straight to the editor claimed every event could be changed, and an
/// invitation from someone else silently refused to save.
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
            case .existing(let event): viewer(for: event)
            }
            presented = controller
            host.present(controller, animated: true)
        }

        /// A new event has nothing to view, so it opens straight in the editor.
        private func editor(startingAt start: Date) -> UIViewController {
            let controller = EKEventEditViewController()
            controller.eventStore = parent.store
            controller.editViewDelegate = self

            let event = EKEvent(eventStore: parent.store)
            event.startDate = start
            event.endDate = start.addingTimeInterval(parent.defaultDuration)
            event.calendar = parent.store.defaultCalendarForNewEvents
            controller.event = event
            return controller
        }

        /// `EKEventViewController` needs a navigation controller: it puts its
        /// own Edit button in the bar, and removes itself from the stack if the
        /// event is deleted underneath it. Presented modally it offers no way
        /// out, so Done goes on the left, where Edit cannot land on top of it.
        private func viewer(for event: EKEvent) -> UIViewController {
            let controller = EKEventViewController()
            controller.event = event
            controller.delegate = self
            // Allowing it is not the same as showing it: an event on a
            // read-only calendar, or one someone else invited you to, gets no
            // Edit button no matter what this says.
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
