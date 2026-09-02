import SwiftUI

// TEMPORARY — clear-sky direction study. Strip the losers and the switcher.
enum ClearSkyVariant: String, CaseIterable, Identifiable {
    case field, flock, arcbound
    var id: String { rawValue }
    var title: String {
        switch self {
        case .field: "A · Field"
        case .flock: "B · Flock"
        case .arcbound: "C · Along the arc"
        }
    }
}

/// What a clear sky draws.
///
/// With nothing overhead the band went empty, and an empty band is
/// indistinguishable from weather that never loaded. Stars are the honest half:
/// they are visible precisely when it is clear. Birds are the whimsical half,
/// and are not pretending to be data.
///
/// One view per deck, mounted beside `SkyContinuous`, so the marks inherit that
/// deck's parallax and a nearer cloud fills over them.
struct ClearSky: View, Equatable {
    let day: SolarDay
    let width: CGFloat
    let height: CGFloat
    let hours: [SkyHour]
    let daySeed: Int
    let deck: SkyContinuous.Deck
    let variant: ClearSkyVariant

    /// Marks per day, per deck, at full clearance. The nearest deck carries
    /// fewest: depth is read from density as much as from size.
    private var budget: Int {
        let base: Int
        switch variant {
        case .field: base = 16
        case .flock: base = 5
        case .arcbound: base = 12
        }
        switch deck {
        case .high: return base
        case .mid: return Int(Double(base) * 0.6)
        case .low: return Int(Double(base) * 0.35)
        }
    }

    private var size: CGFloat {
        switch deck {
        case .high: 2.4
        case .mid: 3.0
        case .low: 3.8
        }
    }

    var body: some View {
        // Redrawn on a timeline rather than through animatable state: the
        // twinkle never touches layout, and `Canvas` draws it imperatively, so
        // no part of the view tree re-evaluates per frame.
        TimelineView(.animation(minimumInterval: 1.0 / 12)) { timeline in
            Canvas { context, _ in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                for mark in marks() {
                    draw(mark, in: &context, phase: phase)
                }
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    static func == (a: ClearSky, b: ClearSky) -> Bool {
        a.daySeed == b.daySeed && a.deck == b.deck && a.variant == b.variant
            && a.width == b.width && a.height == b.height && a.hours == b.hours
    }

    // MARK: - Placement

    private struct Mark {
        let point: CGPoint
        let isStar: Bool
        let opacity: Double
        let salt: Int
    }

    /// How much of this hour's sky is free, by this deck's own coverage. A
    /// clearing is a gap in the cloud drawing, so it is a run of marks here.
    private func clearance(_ entry: SkyHour) -> Double {
        let covered = deck.coverage(entry)
        return max(0, 1 - covered / SkyHour.layerThreshold * 0.6).clamped(to: 0...1)
    }

    private func marks() -> [Mark] {
        guard !hours.isEmpty else { return [] }
        let byHour = Dictionary(uniqueKeysWithValues: hours.map { ($0.hour, $0) })
        var result: [Mark] = []

        for index in 0..<budget {
            let salt = index &* 5_701
            let hourRoll = SkyMarks.jitter(daySeed &+ deck.saltBase, salt)
            let hour: Double

            switch variant {
            case .field:
                hour = hourRoll * 24
            case .flock:
                // One cluster a day, so the band has a subject rather than a
                // texture. The whole group shares a centre and scatters around it.
                let centre = SkyMarks.jitter(daySeed &+ deck.saltBase, 31) * 20 + 2
                hour = centre + (hourRoll - 0.5) * 3.2
            case .arcbound:
                // Pulled toward solar noon, where the arc is highest, so the
                // sky thickens with the day rather than lying flat across it.
                let pull = SkyMarks.jitter(daySeed &+ deck.saltBase, salt &+ 17)
                hour = 12 + (hourRoll - 0.5) * 24 * (0.35 + pull * 0.5)
            }

            guard hour >= 0, hour < 24 else { continue }
            guard let entry = byHour[min(max(Int(hour), 0), 23)] else { continue }

            let free = clearance(entry)
            guard free > 0.15 else { continue }

            // Night and day are one crossfade, not a switch: the arc pans
            // through dusk under the thumb, so this has to be continuous.
            let elevation = day.normalizedElevation(atHour: hour)
            let night = (1 - elevation * 6).clamped(to: 0...1)
            let isStar = SkyMarks.jitter(daySeed, salt &+ 3) < night
            let presence = isStar ? night : 1 - night
            guard presence > 0.2 else { continue }

            // Out along the normal, jittered within the deck's own band so the
            // marks occupy a stratum rather than sitting on one line.
            let spread = SkyMarks.jitter(daySeed &+ deck.saltBase, salt &+ 41)
            let out = deck.offset + CGFloat(spread - 0.5) * 26

            result.append(Mark(point: point(hour: hour, out: out),
                               isStar: isStar,
                               opacity: free * presence,
                               salt: salt))
        }
        return result
    }

    // MARK: - Drawing

    private func draw(_ mark: Mark, in context: inout GraphicsContext, phase: Double) {
        let base = Theme.ink.opacity(SkyMarks.inkOpacity)

        if mark.isStar {
            // Each star keeps its own period and offset, so the field breathes
            // instead of pulsing in unison.
            let period = 2.6 + SkyMarks.jitter(daySeed, mark.salt &+ 601) * 3.4
            let offset = SkyMarks.jitter(daySeed, mark.salt &+ 809) * period
            let wave = (sin((phase + offset) / period * 2 * .pi) + 1) / 2
            let twinkle = 0.45 + wave * 0.55

            let radius = size * 0.55
            var path = Path()
            path.move(to: CGPoint(x: mark.point.x - radius * 1.9, y: mark.point.y))
            path.addQuadCurve(to: CGPoint(x: mark.point.x, y: mark.point.y - radius * 1.9),
                              control: mark.point)
            path.addQuadCurve(to: CGPoint(x: mark.point.x + radius * 1.9, y: mark.point.y),
                              control: mark.point)
            path.addQuadCurve(to: CGPoint(x: mark.point.x, y: mark.point.y + radius * 1.9),
                              control: mark.point)
            path.addQuadCurve(to: CGPoint(x: mark.point.x - radius * 1.9, y: mark.point.y),
                              control: mark.point)
            context.fill(path, with: .color(base.opacity(mark.opacity * twinkle)))
        } else {
            // Two strokes meeting, the way a bird reads at this size. Lean
            // varies so a flock is not a row of identical ticks.
            let lean = (SkyMarks.jitter(daySeed, mark.salt &+ 907) - 0.5) * 0.7
            let wing = size * 1.5
            var path = Path()
            path.move(to: CGPoint(x: mark.point.x - wing, y: mark.point.y + wing * 0.45 - wing * lean))
            path.addQuadCurve(to: mark.point,
                              control: CGPoint(x: mark.point.x - wing * 0.5, y: mark.point.y - wing * 0.35))
            path.addQuadCurve(to: CGPoint(x: mark.point.x + wing, y: mark.point.y + wing * 0.45 + wing * lean),
                              control: CGPoint(x: mark.point.x + wing * 0.5, y: mark.point.y - wing * 0.35))
            context.stroke(path, with: .color(base.opacity(mark.opacity)),
                           style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: - Geometry, matched to the decks

    private func placement(_ hour: Double) -> (point: CGPoint, angle: Double) {
        let delta = 0.35
        func x(_ h: Double) -> CGFloat { width * (h / 24) }
        func y(_ h: Double) -> CGFloat {
            ArcGeometry.y(normalized: day.normalizedElevation(atHour: h), height: height)
        }
        let angle = atan2(y(hour + delta) - y(hour - delta), x(hour + delta) - x(hour - delta))
        return (CGPoint(x: x(hour), y: y(hour)), angle)
    }

    private func point(hour: Double, out: CGFloat) -> CGPoint {
        let base = placement(hour)
        return CGPoint(x: base.point.x + sin(base.angle) * out,
                       y: base.point.y - cos(base.angle) * out)
    }
}
