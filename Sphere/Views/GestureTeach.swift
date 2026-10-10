import SwiftUI

/// How five gestures become findable: a hand that shows them, and an arc that looks like it
/// moves. Chosen 2026-10-10 over a third variant that lived in the day menu; the bake-off and
/// why that one lost are in DECISIONS.
///
/// Three earlier attempts in this app all assumed the gesture must be EXPLAINED — the arc tap
/// was removed on 2026-09-01 because nothing could label it, `WheelTip` names a gesture on a
/// card, and `WheelSettings`' own comment said its first job was documentation. The edge fade
/// below assumes it must be VISIBLE instead, and is the only part of this that leaves nothing
/// behind: no state, no dismissal, nothing to find.
/// A — a fingertip doing each gesture on the real arc, one word under it.
///
/// Only the two that cannot teach themselves get a beat each at full length; drag and pinch get
/// shorter ones because a surface that follows your finger explains itself in the first few
/// millimetres, and anyone who has used Photos will try a pinch on anything that looks zoomable.
struct GhostHand: View {
    let mark: Color
    var onFinish: () -> Void = {}

    @State private var beat = 0
    @State private var slide: CGFloat = 0
    @State private var press: CGFloat = 0
    @State private var spread: CGFloat = 0

    private struct Beat { let word: String; let fingers: Int }
    private static let beats = [
        Beat(word: "drag to move through the day", fingers: 1),
        Beat(word: "tap an hour to make something", fingers: 1),
        Beat(word: "hold for the menu", fingers: 1),
        Beat(word: "two fingers to come back to now", fingers: 2),
        Beat(word: "pinch to see more of the day", fingers: 2),
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
                    .opacity(beat == 2 ? 1 : 0)

                HStack(spacing: current.fingers == 2 ? 26 + spread : 0) {
                    fingertip
                    if current.fingers == 2 { fingertip }
                }
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
            slide = 0; press = 0; spread = 0
            switch index {
            case 0: withAnimation(.easeInOut(duration: 1.1)) { slide = -70 }
                    try? await Task.sleep(for: .milliseconds(1_200))
                    withAnimation(.easeInOut(duration: 1.1)) { slide = 60 }
            case 1: withAnimation(.easeOut(duration: 0.18)) { press = 1 }
                    try? await Task.sleep(for: .milliseconds(200))
                    withAnimation(.easeIn(duration: 0.18)) { press = 0 }
            case 2: withAnimation(.linear(duration: 0.45)) { press = 1 }
            case 3: withAnimation(.easeOut(duration: 0.16)) { spread = -4 }
                    try? await Task.sleep(for: .milliseconds(180))
                    withAnimation(.easeIn(duration: 0.16)) { spread = 0 }
            default: withAnimation(.easeInOut(duration: 1.0)) { spread = 58 }
            }
            try? await Task.sleep(for: .milliseconds(index == 0 ? 2_600 : 1_900))
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
