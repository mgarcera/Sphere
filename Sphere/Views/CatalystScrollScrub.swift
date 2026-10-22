import SwiftUI
#if targetEnvironment(macCatalyst)
import UIKit
#endif

/// Scrubbing the day with a trackpad or a scroll wheel (Mason, 2026-10-21, on the first Mac build:
/// "can we have the arc scrubbing respond to all scrolling? up/down and left/right?").
///
/// **SwiftUI gestures never see a scroll.** `DragGesture` is fed by touches and by an indirect
/// pointer drag, and a two-finger trackpad scroll is neither — so on a Mac the arc answered a
/// click-and-drag and ignored the gesture every Mac user reaches for first. The only way across is
/// a `UIPanGestureRecognizer` with `allowedScrollTypesMask`, which is the documented route for
/// routing scroll events into a pan, available since iOS 13.4 and present on Catalyst.
///
/// **The recogniser goes on an ANCESTOR, which is what the first version got wrong.** A gesture
/// recogniser only fires for events delivered to its own view or a descendant of it. Putting the
/// catcher in `.background()` makes it a sibling sitting *behind* the drawing, so every scroll
/// landed on the arc, walked up a responder chain that does not pass through the catcher, and did
/// nothing at all. It now attaches the recogniser to its `superview` — the container that holds
/// the catcher and the drawing both — and re-checks on every update in case SwiftUI re-parents it.
///
/// **It is scroll-only, by handler rather than by configuration.** A scroll arrives as a pan with
/// no touches, so `numberOfTouches > 0` is a pointer drag that `DragGesture` already owns and is
/// dropped. The first version instead set `allowedTouchTypes = []`, betting that a recogniser
/// accepting no touch types would still be handed scroll events; that bet was never tested and is
/// not worth making, since `cancelsTouchesInView = false` plus the count check achieves the same
/// separation out of documented behaviour.
///
/// **Horizontal scrubs, vertical zooms, and that split came from the device.** Both axes moved
/// time in the first working build, and Mason reported horizontal smooth while vertical "stops at
/// different intervals… I can't use up/down continuously". That is the deciding fact rather than a
/// taste: scrubbing is continuous and breaks visibly when its input stutters, while a zoom is
/// perfectly happy arriving in steps. So the axis that cannot do continuous motion gets the job
/// that never needed it, which is also the convention a map or a timeline already uses for a
/// scroll wheel. The stutter itself is undiagnosed and is now harmless.
extension View {
    /// `onScroll` is handed raw point deltas, horizontal then vertical, and the caller decides
    /// what each axis means — this stays ignorant of hours and of zoom.
    func catalystScrollScrub(onBegan: @escaping () -> Void,
                             onScroll: @escaping (CGFloat, CGFloat) -> Void) -> some View {
        #if targetEnvironment(macCatalyst)
        // A background rather than an overlay, and WITHOUT `allowsHitTesting(false)`: that
        // modifier would switch off the very interaction the recogniser needs, so the catcher
        // stays hit-testable and sits behind the drawing, where the foreground takes touches
        // first and a scroll — which no SwiftUI view consumes — falls through to it.
        background(
            ScrollScrubCatcher(onBegan: onBegan, onScroll: onScroll)
        )
        #else
        self
        #endif
    }
}

#if targetEnvironment(macCatalyst)

private struct ScrollScrubCatcher: UIViewRepresentable {
    var onBegan: () -> Void
    var onScroll: (CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.backgroundColor = .clear
        view.coordinator = context.coordinator
        context.coordinator.apply(self)
        return view
    }

    func updateUIView(_ uiView: CatcherView, context: Context) {
        // Points per hour changes with the zoom and the window width, so the coordinator reads
        // the current value rather than capturing the one it was built with.
        context.coordinator.apply(self)
        // SwiftUI may rebuild the hierarchy around us; re-home the recogniser if it has.
        uiView.attachToAncestor()
    }

    /// Without this the catcher measures {0, 0} and never covers the arc at all — which is what
    /// the first build did, silently. A `UIViewRepresentable` is sized from its intrinsic content
    /// size, and a bare `UIView` has none, so it collapses rather than filling its background slot.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CatcherView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    /// Exists only to learn when it has a superview, which is where the recogniser must live.
    final class CatcherView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            attachToAncestor()
        }

        /// The WINDOW, not the superview. Walking up one level lands on SwiftUI's own wrapper for
        /// this representable — `UIKitPlatformViewHost<PlatformViewRepresentableAdaptor<…>>` —
        /// which contains the catcher and nothing else, so it is no more an ancestor of the arc
        /// than the catcher was. The window is the one view guaranteed to be above everything,
        /// and the handler scopes events back to this view's own frame.
        func attachToAncestor() {
            guard let coordinator, let window else { return }
            coordinator.attach(to: window, scopedTo: self)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private var onBegan: () -> Void = {}
        private var onScroll: (CGFloat, CGFloat) -> Void = { _, _ in }
        private var last: CGPoint = .zero
        private weak var attachedTo: UIView?
        /// The arc's own frame. The recogniser lives on the window, so this is what keeps a
        /// scroll over the menu or the header from moving the day.
        private weak var scope: UIView?
        private var pan: UIPanGestureRecognizer?

        func apply(_ view: ScrollScrubCatcher) {
            onBegan = view.onBegan
            onScroll = view.onScroll
        }

        /// Puts the recogniser on `host`, which must be an ancestor of the drawing, and moves it
        /// if SwiftUI hands us a different one later.
        func attach(to host: UIView, scopedTo area: UIView) {
            scope = area
            guard attachedTo !== host else { return }
            if let pan, let old = attachedTo { old.removeGestureRecognizer(pan) }
            let recogniser = pan ?? {
                let p = UIPanGestureRecognizer(target: self, action: #selector(handle(_:)))
                // Discrete is a wheel notch, continuous is a trackpad glide. Both are scrubbing.
                p.allowedScrollTypesMask = .all
                // Never swallow or delay a touch: the SwiftUI drag and tap keep working, and
                // this one only acts on the scrolls they cannot see.
                p.cancelsTouchesInView = false
                p.delaysTouchesBegan = false
                p.delaysTouchesEnded = false
                p.delegate = self
                pan = p
                return p
            }()
            host.addGestureRecognizer(recogniser)
            attachedTo = host
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        @objc func handle(_ pan: UIPanGestureRecognizer) {
            // A scroll is a pan with no touches. Anything with touches is a pointer drag that
            // DragGesture already owns, and acting on it would move the day twice per drag.
            guard pan.numberOfTouches == 0 else { return }
            // The recogniser is on the window, so an event anywhere in it arrives here. Only
            // scrolls that land on the arc should move the day.
            guard let scope, scope.bounds.contains(pan.location(in: scope)) else { return }
            switch pan.state {
            case .began:
                last = .zero
                onBegan()
            case .changed:
                let now = pan.translation(in: pan.view)
                // Deltas, not the running total: the same reason `scrubGesture` keeps its own
                // `lastTranslation`. Sending the cumulative value each callback compounds it
                // into an accelerating slide.
                let delta = CGPoint(x: now.x - last.x, y: now.y - last.y)
                last = now
                onScroll(delta.x, delta.y)
            case .ended, .cancelled, .failed:
                last = .zero
            default:
                break
            }
        }
    }
}

#endif
