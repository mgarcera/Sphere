import SwiftUI

/// What a sheet needs on a Mac that it does not need on a phone.
///
/// Two separate faults, both from the same cause — **Catalyst ignores `presentationDetents`** —
/// and both reported by Mason against the first Mac build on 2026-10-21.
///
/// **A sheet has no visible way out.** Every sheet here hides its drag indicator, and that was a
/// decision rather than an oversight: the note at `ContentView.swift:259` records it being shown
/// for one build and taken back, because "a grabber over a page of hands is one more mark
/// competing with the six being demonstrated, and a sheet drags down whether or not it says so".
/// The second half of that sentence stops being true on a Mac, where a downward drag dismisses
/// nothing and `Escape` works only while the app is frontmost, with nothing saying so.
///
/// **And the sheet is enormous.** A sheet sized for a 200-point phone detent becomes a large
/// centred card with its content pinned to the top and the rest empty. `presentationSizing(.fitted)`
/// is the replacement — it sizes the presentation to the content rather than to a detent, and is
/// available on Catalyst from iOS 18, well under this app's floor of 26.
///
/// **It compiles to `self` on iOS.** The conditional is on the extension, not inside a view
/// builder, so on iPhone this function body is one word and the phone keeps the appearance Mason
/// settled on. Verified from the object files rather than from reading the source: the iOS build
/// of this file carries 0 references to `Button` against Catalyst's 9.
///
/// `FeedbackSheet` is the one sheet not using this; it already carries its own control.
#if targetEnvironment(macCatalyst)
extension View {
    /// Adds a close control, and by default sizes the sheet to its content.
    ///
    /// `close` should do exactly what dismissing by gesture does on iOS — usually setting the same
    /// binding to false — so a sheet with an `onDismiss` handler runs it either way.
    ///
    /// `fitted` is false for the one sheet that genuinely wants the whole height: the day menu is
    /// a settings list, asked for `.large` on iOS, and sizing it to its content would make it a
    /// card that grows past the window instead of a panel that scrolls.
    @ViewBuilder
    func catalystSheet(dismiss close: @escaping () -> Void, fitted: Bool = true) -> some View {
        // A branch rather than a ternary: the three sizings are distinct concrete types and
        // SwiftUI vends no type-erased wrapper for them, so `?:` will not typecheck.
        Group {
            if fitted {
                presentationSizing(.fitted)
            } else {
                presentationSizing(.page)
            }
        }
        .overlay(alignment: .topTrailing) {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 28, height: 28)
                        .contentShape(.rect)
                }
                // Plain, or Catalyst draws a bordered push button, which is a second mark
                // competing with the content — the same objection that hid the grabber on iOS.
                .buttonStyle(.plain)
                .padding(.top, 10)
                .padding(.trailing, 10)
                .accessibilityLabel("Close")
        }
    }
}
#else
extension View {
    /// No-op on iOS: the sheet already drags down, and the detents already size it.
    func catalystSheet(dismiss close: @escaping () -> Void, fitted: Bool = true) -> some View {
        self
    }
}
#endif
