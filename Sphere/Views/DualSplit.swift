import SwiftUI

// TEMPORARY — Dual mode direction study. Strip the losers and the switcher.
enum DualVariant: String, CaseIterable, Identifiable {
    case ground, sky, tide
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ground: "A · Ground"
        case .sky: "B · Sky"
        case .tide: "C · Tide"
        }
    }
}

/// The arc's position on screen, published upward so the whole window can be
/// split along it. Nothing else knows where the curve is: it is drawn three day
/// layers deep inside a panning stack.
struct DualSplit: Equatable {
    /// The visible curve, in the root's coordinate space.
    var curve: Path = Path()
    /// Where the dot sits, which is the sun's current height on screen.
    var level: CGFloat = 0
}

struct DualSplitKey: PreferenceKey {
    static let defaultValue = DualSplit()
    static func reduce(value: inout DualSplit, nextValue: () -> DualSplit) {
        value = nextValue()
    }
}

/// Two grounds, divided by the day itself.
///
/// Drawn as one shape blended with `.difference` over the finished interface
/// rather than as a second colour scheme. That is what makes everything
/// crossing the line come out right for free — the dot sitting on the curve,
/// a capsule half in each half, the hour labels below it, the clouds above —
/// where inverting them individually would mean clipping every layer twice.
struct DualOverlay: View {
    let split: DualSplit
    let size: CGSize
    let variant: DualVariant

    /// Far enough past the screen that the closing edges never show.
    private static let reach: CGFloat = 3_000

    var body: some View {
        region
            .fill(.white)
            .blendMode(.difference)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }

    private var region: Path {
        var path = Path()
        switch variant {
        case .ground, .sky:
            guard !split.curve.isEmpty else { return path }
            path = split.curve
            // Close the curve against one edge or the other. Which edge is the
            // whole question: under the arc is the ground, over it is the sky.
            let edge = variant == .ground ? size.height + Self.reach : -Self.reach
            path.addLine(to: CGPoint(x: size.width + Self.reach, y: edge))
            path.addLine(to: CGPoint(x: -Self.reach, y: edge))
            path.closeSubpath()
        case .tide:
            // Not the curve at all: a level set by where the sun is right now,
            // so the screen fills and drains with the day rather than being
            // cut by its shape.
            path.addRect(CGRect(x: -Self.reach, y: -Self.reach,
                                width: size.width + Self.reach * 2,
                                height: split.level + Self.reach))
        }
        return path
    }
}
