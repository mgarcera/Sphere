import SwiftUI

/// One gesture, as a word and an animation of a hand doing it.
///
/// Three earlier attempts in this app all assumed a gesture must be EXPLAINED — the arc tap was
/// removed on 2026-09-01 because nothing could label it, `WheelTip` named a gesture on a card
/// (deleted 2026-10-10), and `WheelSettings`' own comment said its first job was documentation.
/// What replaced them shows the gesture instead of describing it, which is the whole reason the
/// hand exists: a fingertip doing the thing, with one line under it.
struct GestureLesson: Identifiable {
    enum Kind { case drag, tap, twoFingerTap, hold, pinch }

    let id: String
    let word: String
    let fingers: Int
    let kind: Kind

    /// Mason's words and Mason's order (2026-10-10). Drag leads because it is the one the arc's
    /// edge fade already hints at, so the guide opens on the gesture the screen has
    /// half-introduced; the two ways to the menu close it as one sentence broken over two pages,
    /// which is why the last two read as a trailing clause rather than as separate rules.
    static let all = [
        GestureLesson(id: "drag", word: "Drag to move.", fingers: 1, kind: .drag),
        GestureLesson(id: "pinch", word: "Pinch in and out to zoom.", fingers: 2, kind: .pinch),
        GestureLesson(id: "tap",
                      word: "Tap to jump to now, create an event, open an event, or pick a date.",
                      fingers: 1, kind: .tap),
        GestureLesson(id: "edge",
                      word: "Tap the left or right edges to jump between events.",
                      fingers: 1, kind: .tap),
        GestureLesson(id: "twoFinger", word: "Either tap two fingers for the menu…", fingers: 2, kind: .twoFingerTap),
        GestureLesson(id: "hold", word: "…or hold.", fingers: 1, kind: .hold),
    ]
}

/// The hand, doing ONE gesture, on a loop for as long as its page is the one being read.
///
/// It ran as a timed sequence of all six until 2026-10-10, auto-advancing over the arc. Paging
/// is better for the same reason a sequence was worse: the reader sets the pace, so a gesture
/// they are still working out repeats instead of leaving, and `.task(id:)` below is what ties
/// the loop to the page rather than to the clock.
struct GestureDemo: View {
    let lesson: GestureLesson
    let mark: Color
    /// Whether this page is the one on screen. Every page in a `TabView` stays alive, so without
    /// this all six would animate at once behind each other.
    var isActive: Bool

    static let height: CGFloat = 72

    @State private var slide: CGFloat = 0
    @State private var press: CGFloat = 0
    @State private var spread: CGFloat = 0
    /// The press itself. 0.96 and never lower: below 0.95 a press reads as exaggerated rather
    /// than as a touch.
    @State private var pop: CGFloat = 1

    var body: some View {
        ZStack {
            // The press ring: fills over the same 0.45s the real long press needs, so the
            // demonstration and the gesture agree on how long "hold" is.
            Circle()
                .trim(from: 0, to: press)
                .stroke(mark.opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(-90))
                .opacity(lesson.kind == .hold ? 1 : 0)

            HStack(spacing: lesson.fingers == 2 ? 26 + spread : 0) {
                fingertip
                if lesson.fingers == 2 { fingertip }
            }
            .scaleEffect(pop)
            .offset(x: slide)
        }
        .frame(height: Self.height)
        .task(id: isActive) {
            guard isActive else { return }
            while !Task.isCancelled { await beat() }
        }
    }

    private var fingertip: some View {
        Circle()
            .fill(mark.opacity(0.22))
            .overlay(Circle().strokeBorder(mark.opacity(0.55), lineWidth: 1.5))
            .frame(width: 34, height: 34)
    }

    private func beat() async {
        slide = 0; press = 0; spread = 0; pop = 1
        switch lesson.kind {
        case .drag:
            withAnimation(.easeInOut(duration: 1.1)) { slide = -70 }
            try? await Task.sleep(for: .milliseconds(1_200))
            withAnimation(.easeInOut(duration: 1.1)) { slide = 60 }
        case .tap, .twoFingerTap:
            // Down fast and flat, back on a spring that overshoots a little, which is what makes
            // it read as a tap rather than as a shrink. Twice, because one pop at this size is
            // easy to miss.
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
        // The drag covers the most ground, so it gets the longest rest before it repeats.
        try? await Task.sleep(for: .milliseconds(lesson.kind == .drag ? 2_600 : 1_900))
    }
}

/// The arc gains the one honest signifier a horizontally scrolling surface has: its content fades
/// at both edges, which says "there is more of this that way" because there is. Permanent,
/// wordless, and it never has to be dismissed or found.
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
