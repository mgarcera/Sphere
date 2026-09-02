import EventKit
import EventKitUI
import SwiftUI

/// What the centre button opens: Apple's own editor, either on a new event at
/// the wheel's hour or on the event the dot is currently inside. The existing
/// case carries Delete Event at the bottom, so removal comes free too.
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

/// An invisible host that PRESENTS the editor itself rather than being a
/// SwiftUI sheet's content.
///
/// As sheet content, the controller dismisses itself as part of completing, and
/// inside a sheet that SwiftUI owns that dismissal goes nowhere and takes the
/// callback with it. Presented from a real view controller its own lifecycle
/// works, so saving and cancelling both report back.
///
/// Deleting never does, on any presentation: it commits to the store and skips
/// the delegate entirely. `closeIfEventDeleted` below is what covers it.
struct EventEditorHost: UIViewControllerRepresentable {
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

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        var parent: EventEditorHost
        private var isWaiting = false
        private var waitDeadline: Date?

        init(parent: EventEditorHost) {
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
        /// Opening the editor from another sheet asks to present while that
        /// sheet is still on its way out, which UIKit refuses. SwiftUI does not
        /// call `updateUIViewController` again when it does, so bailing dropped
        /// the target until an unrelated re-render happened along — ten seconds,
        /// in the trace, and variable. Waiting for the presentation to clear is
        /// what makes an all-day event open at the tap.
        func sync(_ host: UIViewController) {
            guard let target = parent.target else {
                waitDeadline = nil
                if host.presentedViewController is EKEventEditViewController {
                    host.dismiss(animated: true)
                }
                return
            }
            guard host.view.window != nil else { return }
            guard !(host.presentedViewController is EKEventEditViewController) else { return }

            guard host.presentedViewController == nil else {
                waitForPresentationToClear(host)
                return
            }

            waitDeadline = nil
            let controller = EKEventEditViewController()
            controller.eventStore = parent.store
            controller.editViewDelegate = self

            switch target {
            case .new(let start):
                let event = EKEvent(eventStore: parent.store)
                event.startDate = start
                event.endDate = start.addingTimeInterval(parent.defaultDuration)
                event.calendar = parent.store.defaultCalendarForNewEvents
                controller.event = event
            case .existing(let event):
                controller.event = event
            }

            host.present(controller, animated: true)
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

        /// Deleting commits to the store and never calls the delegate — saving
        /// and cancelling both do. So the editor sat open over an event that
        /// was already gone, and nothing reloaded until the next launch. The
        /// store's own change notification is the only signal that it happened.
        private func closeIfEventDeleted() {
            guard case .existing(let event)? = parent.target,
                  let identifier = event.eventIdentifier,
                  parent.store.event(withIdentifier: identifier) == nil
            else { return }
            parent.target = nil
            parent.onFinish()
        }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true) { [parent] in
                parent.target = nil
                parent.onFinish()
            }
        }
    }
}
