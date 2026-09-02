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
/// Stars belong to the high deck and birds to the low one, never sharing a
/// level: a bird at star altitude is the one thing that reads as wrong rather
/// than as stylised.
struct ClearSky: View, Equatable {
    let day: SolarDay
    let width: CGFloat
    let height: CGFloat
    let hours: [SkyHour]
    let daySeed: Int
    let deck: SkyContinuous.Deck
    let variant: ClearSkyVariant

    /// Stars are a field and birds are an accident of a nice day, so their
    /// counts are not on the same scale. The middle deck draws neither: it is
    /// the one that would put them at the same altitude.
    private var budget: Int {
        switch deck {
        case .high: variant == .flock ? 7 : 18
        case .mid: 0
        case .low: variant == .flock ? 2 : 3
        }
    }

    private var drawsStars: Bool { deck == .high }

    var body: some View {
        // Computed HERE, outside the timeline's closure, so the hashing and the
        // trigonometry run once per update rather than once per frame. Left
        // inside, nine of these recomputing every tick was the whole of the lag.
        let marks = marks()

        if drawsStars && !marks.isEmpty {
            TimelineView(.animation(minimumInterval: 1.0 / 10, paused: false)) { timeline in
                Canvas { context, _ in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                    for mark in marks { star(mark, in: &context, phase: phase) }
                }
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)
        } else {
            // Birds do not twinkle, so nothing here needs a clock.
            Canvas { context, _ in
                for mark in marks { bird(mark, in: &context) }
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)
        }
    }

    static func == (a: ClearSky, b: ClearSky) -> Bool {
        a.daySeed == b.daySeed && a.deck == b.deck && a.variant == b.variant
            && a.width == b.width && a.height == b.height && a.hours == b.hours
    }

    // MARK: - Placement

    private struct Mark {
        let point: CGPoint
        let opacity: Double
        let salt: Int
    }

    /// Birds only when the whole column is clear, not merely when their own
    /// deck is. A bird under a high overcast is the case that made them read as
    /// decoration rather than as weather.
    private func isClear(_ entry: SkyHour) -> Bool {
        entry.cloudLow < SkyHour.layerThreshold
            && entry.cloudMid < SkyHour.layerThreshold
            && entry.cloudHigh < SkyHour.layerThreshold
            && entry.precipitation <= 0
    }

    private func marks() -> [Mark] {
        guard budget > 0, !hours.isEmpty else { return [] }
        let byHour = Dictionary(uniqueKeysWithValues: hours.map { ($0.hour, $0) })
        var result: [Mark] = []

        for index in 0..<budget {
            let salt = index &* 5_701
            let roll = SkyMarks.jitter(daySeed &+ deck.saltBase, salt)
            let hour: Double

            switch variant {
            case .field:
                hour = roll * 24
            case .flock:
                // One cluster a day, so the band has a subject rather than a
                // texture. The group shares a centre and scatters around it.
                let centre = SkyMarks.jitter(daySeed &+ deck.saltBase, 31) * 20 + 2
                hour = centre + (roll - 0.5) * 3.2
            case .arcbound:
                // Pulled toward solar noon, so the sky thickens where the arc
                // is highest rather than lying flat across the day.
                let pull = SkyMarks.jitter(daySeed &+ deck.saltBase, salt &+ 17)
                hour = 12 + (roll - 0.5) * 24 * (0.35 + pull * 0.5)
            }

            guard hour >= 0, hour < 24, let entry = byHour[Int(hour)] else { continue }

            // Night and day are one crossfade, not a switch: the arc pans
            // through dusk under the thumb, so this has to be continuous.
            let elevation = day.normalizedElevation(atHour: hour)
            let night = (1 - elevation * 6).clamped(to: 0...1)

            let presence: Double
            if drawsStars {
                let free = (1 - deck.coverage(entry) / SkyHour.layerThreshold * 0.6).clamped(to: 0...1)
                presence = night * free
            } else {
                guard isClear(entry) else { continue }
                presence = 1 - night
            }
            guard presence > 0.25 else { continue }

            // Out along the normal, jittered within the deck's own band so the
            // marks occupy a stratum rather than sitting on one line.
            let spread = SkyMarks.jitter(daySeed &+ deck.saltBase, salt &+ 41)
            let out = deck.offset + CGFloat(spread - 0.5) * (drawsStars ? 30 : 16)

            result.append(Mark(point: point(hour: hour, out: out),
                               opacity: presence,
                               salt: salt))
        }
        return result
    }

    // MARK: - Drawing

    /// On or off, never in between. Each star keeps its own period and phase,
    /// and the off window is short, so the field winks rather than pulses.
    private func star(_ mark: Mark, in context: inout GraphicsContext, phase: Double) {
        let period = 3.0 + SkyMarks.jitter(daySeed, mark.salt &+ 601) * 5.0
        let offset = SkyMarks.jitter(daySeed, mark.salt &+ 809) * period
        guard (phase + offset).truncatingRemainder(dividingBy: period) > period * 0.14 else { return }

        let radius: CGFloat = 2.4
        var path = Path()
        path.move(to: CGPoint(x: mark.point.x - radius, y: mark.point.y))
        path.addQuadCurve(to: CGPoint(x: mark.point.x, y: mark.point.y - radius), control: mark.point)
        path.addQuadCurve(to: CGPoint(x: mark.point.x + radius, y: mark.point.y), control: mark.point)
        path.addQuadCurve(to: CGPoint(x: mark.point.x, y: mark.point.y + radius), control: mark.point)
        path.addQuadCurve(to: CGPoint(x: mark.point.x - radius, y: mark.point.y), control: mark.point)
        context.fill(path, with: .color(Theme.ink.opacity(SkyMarks.inkOpacity * mark.opacity)))
    }

    /// Two strokes meeting, the way a bird reads at this size. Lean varies so a
    /// pair is not two identical ticks.
    private func bird(_ mark: Mark, in context: inout GraphicsContext) {
        let lean = (SkyMarks.jitter(daySeed, mark.salt &+ 907) - 0.5) * 0.7
        let wing: CGFloat = 5
        var path = Path()
        path.move(to: CGPoint(x: mark.point.x - wing, y: mark.point.y + wing * 0.45 - wing * lean))
        path.addQuadCurve(to: mark.point,
                          control: CGPoint(x: mark.point.x - wing * 0.5, y: mark.point.y - wing * 0.35))
        path.addQuadCurve(to: CGPoint(x: mark.point.x + wing, y: mark.point.y + wing * 0.45 + wing * lean),
                          control: CGPoint(x: mark.point.x + wing * 0.5, y: mark.point.y - wing * 0.35))
        context.stroke(path, with: .color(Theme.ink.opacity(SkyMarks.inkOpacity * mark.opacity)),
                       style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round))
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
