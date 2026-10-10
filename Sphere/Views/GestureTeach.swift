import SwiftUI

/// How five gestures become findable: a hand that shows them, and an arc that looks like it
/// moves. Chosen 2026-10-10 over a third variant that lived in the day menu; the bake-off and
/// why that one lost are in DECISIONS.
///
/// Three earlier attempts in this app all assumed the gesture must be EXPLAINED — the arc tap
/// was removed on 2026-09-01 because nothing could label it, `WheelTip` named a gesture on a
/// card (deleted 2026-10-10, once this replaced it), and `WheelSettings`' own comment said its
/// first job was documentation. The edge fade
/// below assumes it must be VISIBLE instead, and is the only part of this that leaves nothing
/// behind: no state, no dismissal, nothing to find.
/// A — a fingertip doing each gesture on the real arc, one word under it.
///
/// Only the two that cannot teach themselves get a beat each at full length; drag and pinch get
/// shorter ones because a surface that follows your finger explains itself in the first few
/// millimetres, and anyone who has used Photos will try a pinch on anything that looks zoomable.
///
/// That is the intent and NOT what the timing does (found 2026-10-10): the drag beat runs 2,600ms
/// and every other beat 1,900ms, so the drag is the longest rather than the shortest. Left as it
/// is because the drag has the most to show, and the comment above is now a note on what was
/// meant rather than a claim about the code.
struct GhostHand: View {
    /// What the hand needs vertically: the 72-point fingertip row, the 28-point gap, and a
    /// caption that wraps to two lines at the longest beat. The caller lifts the hand by exactly
    /// this to clear the arc block's top edge (ContentView, `day`); it was a band measurement
    /// for one build on 2026-10-10 and is now the lift itself.
    static let height: CGFloat = 134

    let mark: Color
    var onFinish: () -> Void = {}

    @State private var beat = 0
    @State private var slide: CGFloat = 0
    @State private var press: CGFloat = 0
    @State private var spread: CGFloat = 0
    /// The press itself. 0.96 and never lower: below 0.95 a press reads as exaggerated rather
    /// than as a touch.
    @State private var pop: CGFloat = 1

    /// Keyed by KIND rather than by position, so the order below is free to change without the
    /// animations following the wrong beat.
    private enum Kind { case drag, tap, twoFingerTap, hold, pinch }
    private struct Beat { let word: String; let fingers: Int; let kind: Kind }

    /// Mason's order (2026-10-10), with drag leading because it is the one the arc's edge fade
    /// already hints at, so the hand starts on the gesture the screen has half-introduced.
    /// Mason's words, except the drag and the three added on 2026-10-10 when the gestures moved
    /// (the edge bands, and the menu and the hold trading places). Those three are placeholders
    /// until he writes them.
    private static let beats = [
        Beat(word: "drag to move through the day", fingers: 1, kind: .drag),
        Beat(word: "tap to create or open an event", fingers: 1, kind: .tap),
        Beat(word: "tap the left or right edge to jump a day", fingers: 1, kind: .tap),
        Beat(word: "tap two fingers for the menu", fingers: 2, kind: .twoFingerTap),
        Beat(word: "hold for now, or another day", fingers: 1, kind: .hold),
        Beat(word: "pinch in and out to zoom", fingers: 2, kind: .pinch),
    ]

    var body: some View {
        let current = Self.beats[min(beat, Self.beats.count - 1)]
        VStack(spacing: 28) {
            ZStack {
                // The press ring: fills over the same 0.45s the real long press needs, so the
                // demonstration and the gesture agree on how long "hold" is.
                Circle()
                    .trim(from: 0, to: press)
                    .stroke(mark.opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                    .opacity(Self.beats[min(beat, Self.beats.count - 1)].kind == .hold ? 1 : 0)

                HStack(spacing: current.fingers == 2 ? 26 + spread : 0) {
                    fingertip
                    if current.fingers == 2 { fingertip }
                }
                .scaleEffect(pop)
                .offset(x: slide)
            }
            .frame(height: 72)

            Text(current.word)
                .font(.footnote)
                .foregroundStyle(mark)
                .contentTransition(.opacity)
        }
        .task { await run() }
    }

    private var fingertip: some View {
        Circle()
            .fill(mark.opacity(0.22))
            .overlay(Circle().strokeBorder(mark.opacity(0.55), lineWidth: 1.5))
            .frame(width: 34, height: 34)
    }

    private func run() async {
        for index in Self.beats.indices {
            beat = index
            slide = 0; press = 0; spread = 0; pop = 1
            switch Self.beats[index].kind {
            case .drag:
                withAnimation(.easeInOut(duration: 1.1)) { slide = -70 }
                try? await Task.sleep(for: .milliseconds(1_200))
                withAnimation(.easeInOut(duration: 1.1)) { slide = 60 }
            case .tap, .twoFingerTap:
                // Down fast and flat, back on a spring that overshoots a little, which is what
                // makes it read as a tap rather than as a shrink. Twice, because one pop at this
                // size is easy to miss.
                for _ in 0..<2 {
                    withAnimation(.easeIn(duration: 0.09)) { pop = 0.96 }
                    try? await Task.sleep(for: .milliseconds(110))
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.55)) { pop = 1 }
                    try? await Task.sleep(for: .milliseconds(360))
                }
            case .hold:
                withAnimation(.easeIn(duration: 0.12)) { pop = 0.96 }
                withAnimation(.linear(duration: 0.45)) { press = 1 }
                try? await Task.sleep(for: .milliseconds(520))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pop = 1 }
            case .pinch:
                withAnimation(.easeInOut(duration: 1.0)) { spread = 58 }
            }
            try? await Task.sleep(for: .milliseconds(Self.beats[index].kind == .drag ? 2_600 : 1_900))
        }
        onFinish()
    }
}

/// B — no teaching layer at all. The arc gains the one honest signifier a horizontally scrolling
/// surface has: its content fades at both edges, which says "there is more of this that way"
/// because there is. Permanent, wordless, and it never has to be dismissed or found.
struct ScrubAffordance: ViewModifier {
    let mark: Color

    func body(content: Content) -> some View {
        content.mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.07),
                .init(color: .black, location: 0.93),
                .init(color: .clear, location: 1),
            ], startPoint: .leading, endPoint: .trailing)
        )
    }
}
