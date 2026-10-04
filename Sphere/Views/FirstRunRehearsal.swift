#if DEBUG
import SwiftUI
import SmidgecraftKit

/// Sphere's first run, steppable on demand.
///
/// It matters more here than in Perzine. A permission prompt fires **once per install**: grant or
/// deny calendar and the screen explaining it is unreachable forever after, so without this the
/// only way to look at these three again is to delete the app, and the only way to look at the
/// second one is to delete the app and get past the first. Two of the three screens were
/// effectively unreviewable (2026-10-04).
///
/// The real views render, with the real copy. The steps' actions are replaced with nothing, so
/// stepping through raises no system prompt — which is the point, and also the limit: this proves
/// each screen is composed and worded right, and proves nothing about the order the gate sends
/// them in. That is what the package's tests and one real install are for.
struct FirstRunRehearsal: View {
    let onClose: () -> Void

    @State private var step = 0

    private let beats: [(id: String, title: String, emphasis: String, message: String, note: String)] = [
        ("calendar", "Your schedule\nin the sky’s arc.", "sky’s",
         "First let’s get your calendar events\nup and running.",
         "Unskippable. Continue, never Allow — the word Fil was rejected over."),
        ("location", "With a real atmosphere.", "",
         "Now let’s get your weather\nand nothing more.",
         "Its own screen, so this prompt is no longer queued behind the first."),
    ]

    var body: some View {
        ZStack {
            OnboardingScreen(title: beats[step].title,
                             emphasis: beats[step].emphasis,
                             message: beats[step].message,
                             action: OnboardingCopy.continueToPermission) {
                withAnimation(.smooth(duration: 0.3)) {
                    step = min(step + 1, beats.count - 1)
                }
            } demo: {
                // No `.id`: the rehearsal has to show the same continuity the real flow has, which
                // is the arc carrying on rather than restarting between the two.
                FirstRunArc(weather: beats[step].id == "location")
            }
        }
        .overlay(alignment: .top) { panel }
    }

    /// Labelled, because a staged state photographs exactly like a shipped one.
    private var panel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FIRST RUN · DEBUG")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.4)
                Spacer()
                Button("Close", action: onClose)
                    .font(.system(size: 11, weight: .medium))
            }

            HStack(spacing: 6) {
                ForEach(beats.indices, id: \.self) { i in
                    Button { withAnimation(.smooth(duration: 0.3)) { step = i } } label: {
                        Text(beats[i].id)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(i == step ? .black : .white.opacity(0.75))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(i == step ? .white : .white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(beats[step].note)
                .font(.system(size: 10.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.62))
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }
}
#endif
