import SwiftUI
import UIKit

/// A two-finger tap, which SwiftUI has no gesture for at any version.
///
/// The question comes from `swiftui-direct-manipulation`, which measured on 2026-10-03 that a
/// `contextMenu` and a zero-distance drag cannot share a touch: with `.gesture` the drag starved
/// the menu, with `.simultaneousGesture` the menu's UIKit interaction starved the drag. That was
/// `UIContextMenuInteraction` specifically, which competes from OUTSIDE the gesture system.
/// `UIGestureRecognizerRepresentable` wraps a recogniser as a real SwiftUI gesture, so it joins
/// the same arena — and a spike on 2026-10-10 confirmed it coexists with the arc's drag, tap,
/// long press and pinch without any of them starving.
struct TwoFingerTap: UIGestureRecognizerRepresentable {
    let action: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let recogniser = UITapGestureRecognizer()
        recogniser.numberOfTouchesRequired = 2
        recogniser.numberOfTapsRequired = 1
        return recogniser
    }

    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        action()
    }
}
