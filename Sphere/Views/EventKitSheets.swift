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
/// As sheet content, deleting an event never called the delegate at all: the
/// controller dismisses itself as part of completing, and inside a sheet that
/// SwiftUI owns, that dismissal goes nowhere and takes the callback with it.
/// Saving happened to survive it; deleting did not. Presented from a real view
/// controller, its own lifecycle works and every action reports back.
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

        guard let target else {
            if host.presentedViewController is EKEventEditViewController {
                host.dismiss(animated: true)
            }
            return
        }
        guard host.presentedViewController == nil, host.view.window != nil else { return }

        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.editViewDelegate = context.coordinator

        switch target {
        case .new(let start):
            let event = EKEvent(eventStore: store)
            event.startDate = start
            event.endDate = start.addingTimeInterval(defaultDuration)
            event.calendar = store.defaultCalendarForNewEvents
            controller.event = event
        case .existing(let event):
            controller.event = event
        }

        host.present(controller, animated: true)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        var parent: EventEditorHost

        init(parent: EventEditorHost) { self.parent = parent }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true) { [parent] in
                parent.target = nil
                parent.onFinish()
            }
        }
    }
}
