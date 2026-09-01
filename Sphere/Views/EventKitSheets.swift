import EventKit
import EventKitUI
import SwiftUI

/// Apple's event editor, opened by the centre button with the start already set
/// to the wheel's hour. Duration, calendar, alerts and recurrence are all its
/// job, not ours.
struct EventEditorSheet: UIViewControllerRepresentable {
    let store: EKEventStore
    let start: Date
    var defaultDuration: TimeInterval = 30 * 60
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.editViewDelegate = context.coordinator

        let event = EKEvent(eventStore: store)
        event.startDate = start
        event.endDate = start.addingTimeInterval(defaultDuration)
        event.calendar = store.defaultCalendarForNewEvents
        controller.event = event

        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            onFinish()
        }
    }
}

/// Apple's detail view, which carries Edit and Delete so we don't build either.
/// It needs a navigation controller around it or those buttons never appear.
struct EventDetailSheet: UIViewControllerRepresentable {
    let event: EKEvent
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = EKEventViewController()
        controller.event = event
        controller.allowsEditing = true
        controller.allowsCalendarPreview = true
        controller.delegate = context.coordinator
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [onFinish] _ in onFinish() }
        )
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, EKEventViewDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func eventViewController(_ controller: EKEventViewController,
                                 didCompleteWith action: EKEventViewAction) {
            onFinish()
        }
    }
}
