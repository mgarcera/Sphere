import SwiftUI
import SmidgecraftKit

/// Sphere's first run: two screens, each one immediately before the thing it explains.
///
/// It replaced `CalendarPriming`, which was a single screen that explained both permissions and
/// then requested both, back to back. iOS queues the second prompt behind the first, so the
/// location prompt arrived with its explanation two screens of attention earlier — and a cold
/// denial is close to permanent. Splitting them is the whole point of this file (2026-10-04).
///
/// Two screens, one per permission, because Sphere is the only one of the three apps that asks
/// for anything at launch and it asks for two things. A third was planned to teach the hold
/// layer so `WheelTip` could be deleted, and was cut: the tip appears on the wheel, pointing at
/// the wheel, and retires itself on the first hold, which is better teaching than a screen shown
/// before anyone has seen a wheel. `WheelTip` stays.
///
/// Both permission steps are `isSkippable: false`. Apple rejected Fil 1.0 build 4 under guideline
/// 5.1.1(iv) for offering a way out of a priming screen without reaching the system alert, and
/// `OnboardingRun.skip()` refuses on an unskippable step so a pager cannot route around one.
struct FirstRunFlow: View {
    let calendar: CalendarService
    let location: LocationService
    let onFinish: () -> Void

    @State private var run: OnboardingRun?

    var body: some View {
        Group {
            if let run, let step = run.current {
                OnboardingScreen(
                    title: step.title,
                    emphasis: emphasis(in: step.id),
                    message: step.body,
                    action: label(for: step),
                    working: run.isWorking
                ) {
                    Task { await run.advance() }
                } demo: {
                    // No `.id` here and none on the screen. Keying the screen remounted this,
                    // which restarted the pan and dropped the dot back where it began. The arc
                    // is one continuous thing across both steps; only the words change, and they
                    // carry the identity instead (2026-10-04).
                    FirstRunArc(weather: step.id == "location")
                }
            }
        }
        .animation(.smooth(duration: 0.35), value: run?.index)
        .task {
            guard run == nil else { return }
            run = OnboardingRun(steps: steps)
        }
        .onChange(of: run?.isFinished) { _, finished in
            if finished == true { onFinish() }
        }
    }

    /// "Continue" before a system alert, never "Allow" or "Enable" — Apple names those as
    /// manipulation on a screen standing in front of a prompt.
    private func label(for step: OnboardingStep) -> String {
        step.isSkippable ? OnboardingCopy.next : OnboardingCopy.continueToPermission
    }

    private var steps: [OnboardingStep] {
        [
            OnboardingStep(
                id: "calendar",
                title: "Your schedule\nin the sky’s arc.",
                body: "First let’s get your calendar events\nup and running.",
                isSkippable: false
            ) {
                await calendar.requestAccess()
            },

            OnboardingStep(
                id: "location",
                title: "With a real atmosphere.",
                body: "Now let’s get your weather\nand nothing more.",
                isSkippable: false
            ) {
                // Not awaited beyond the hop: `request()` returns as soon as the prompt is raised
                // and the delegate answers later, so waiting on it would hold the step open on
                // nothing. The `MainActor.run` is what the isolation requires — without it this
                // compiles today under Swift 5 and is an error under Swift 6 (2026-10-04).
                await MainActor.run { location.request() }
            },
        ]
    }

    /// The word set in italic on each title, matching the App Store assets, where one word in
    /// each line carries the emphasis. Kept beside the titles so the two cannot drift.
    private func emphasis(in stepID: String) -> String {
        // Only the first line carries an italic word, the way the store assets do.
        stepID == "calendar" ? "sky’s" : ""
    }
}

/// One first-run screen. The layout is `CalendarPriming`'s, kept because it was already right:
/// the reason above the fold, one full-width control, nothing else to press.
struct OnboardingScreen<Demo: View>: View {
    let title: String
    /// The one word set in italic, matching the App Store assets. Empty for none.
    var emphasis: String = ""
    /// Named `message` rather than `body` because a stored `body` collides with SwiftUI's.
    let message: String
    let action: String
    var working = false
    let onContinue: () -> Void
    @ViewBuilder var demo: Demo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Group {
                styledTitle
                    .font(.display(30))
                // Set in sky, the way the website's hero is: a gradient clipped to the words and
                // nothing else coloured on the screen. Both ends are blues the app already owns —
                // the capsule blue and ClearBlue's zenith — rather than hexes retyped here, and
                // the range is deliberately the dark half, because the full wash's tail measures
                // 1.75:1 on paper and the last words become a suggestion.
                .foregroundStyle(
                    LinearGradient(colors: [Theme.taskActive,
                                            Color(red: ClearBlue.topComponents.r,
                                                  green: ClearBlue.topComponents.g,
                                                  blue: ClearBlue.topComponents.b)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 40)

                Text(message)
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .padding(.horizontal, 40)
            }
            // Gently, and only the words. A cross-fade here leaves the arc untouched underneath,
            // which is what makes the two screens read as one view changing its caption.
            .id(title)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.55), value: title)

            demo
                .padding(.top, 36)

            Spacer()

            Button(action: onContinue) {
                Text(action)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.ink, in: .capsule)
                    .opacity(working ? 0.5 : 1)
            }
            .buttonStyle(.plain)
            .disabled(working)
            .padding(.horizontal, 40)
        }
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    /// One word italic, the rest roman.
    ///
    /// An `AttributedString` run rather than concatenated `Text`, which iOS 26 deprecates. Marking
    /// the run as emphasised rather than setting a font keeps the size and face from the modifier
    /// outside, so the italic cannot drift from the rest of the line.
    private var styledTitle: Text {
        var attributed = AttributedString(title)
        if !emphasis.isEmpty, let range = attributed.range(of: emphasis) {
            attributed[range].inlinePresentationIntent = .emphasized
        }
        return Text(attributed)
    }
}
