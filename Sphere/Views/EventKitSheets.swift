import EventKit
import EventKitUI
import SwiftUI

/// What the centre button opens: Apple's own editor, either on a new event at
/// the wheel's hour or on the event the dot is currently inside. The existing
/// case carries Delete Event at the bottom, so removal comes free too.
enum EventTarget: Identifiable {
    case new(Date)
    case existing(EKEvent)

    var id: String {
        switch self {
        case .new(let date): "new-\(date.timeIntervalSince1970)"
        case .existing(let event): "edit-\(event.eventIdentifier ?? "")-\(event.startDate.timeIntervalSince1970)"
        }
    }
}

struct EventEditorSheet: UIViewControllerRepresentable {
    let store: EKEventStore
    let target: EventTarget
    var defaultDuration: TimeInterval = 30 * 60
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
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

        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            let name: String
            switch action {
            case .canceled: name = "canceled"
            case .saved: name = "saved"
            case .deleted: name = "deleted"
            @unknown default: name = "unknown"
            }
            Trace.log("editor completed: \(name)")
            onFinish()
        }
    }
}
