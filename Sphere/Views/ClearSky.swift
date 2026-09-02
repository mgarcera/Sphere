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

    /// The scrub position, quantised. Everything else in this app moves because
    /// the wheel moved, and a clock ticking on its own was the one thing that
    /// did not — it also meant nine views redrawing while nothing was happening.
    /// Stars wink as the sky passes instead, so an idle screen is perfectly
    /// still and the cost is bounded by how fast a thumb can turn.
    let blinkStep: Int

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
        let marks = Self.marks(for: self)
        Canvas { context, _ in
            for mark in marks {
                if drawsStars {
                    star(mark, in: &context)
                } else {
                    bird(mark, in: &context)
                }
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    /// Birds hold still, so their decks ignore the scrub entirely and never
    /// redraw while the wheel turns.
    static func == (a: ClearSky, b: ClearSky) -> Bool {
        a.daySeed == b.daySeed && a.deck == b.deck && a.variant == b.variant
            && a.width == b.width && a.height == b.height && a.hours == b.hours
            && (!a.drawsStars || a.blinkStep == b.blinkStep)
    }

    // MARK: - Cache

    private struct Key: Hashable {
        let daySeed: Int
        let deck: SkyContinuous.Deck
        let variant: ClearSkyVariant
        let width: CGFloat
        let height: CGFloat
        /// The weather itself, folded down. Without it the first render — which
        /// happens before the forecast arrives, with no hours at all — cached
        /// an empty sky for every day and deck and never rebuilt it.
        let sky: Int
    }

    private var skySignature: Int {
        var hash = Hasher()
        for entry in hours {
            hash.combine(entry.hour)
            hash.combine(Int(entry.cloudLow * 100))
            hash.combine(Int(entry.cloudMid * 100))
            hash.combine(Int(entry.cloudHigh * 100))
            hash.combine(entry.precipitation > 0)
        }
        return hash.finalize()
    }

    /// Where a mark sits never depends on the scrub, only on the day, so the
    /// hashing and the trigonometry happen once per day rather than on every
    /// redraw. Without this, winking on the scrub would have cost exactly what
    /// winking on a clock did.
    private static var cache: [Key: [Mark]] = [:]

    private static func marks(for view: ClearSky) -> [Mark] {
        // Nothing to place yet, and nothing worth remembering about it.
        guard !view.hours.isEmpty else { return [] }

        let key = Key(daySeed: view.daySeed, deck: view.deck, variant: view.variant,
                      width: view.width, height: view.height, sky: view.skySignature)
        if let hit = cache[key] { return hit }
        // Scrubbing far enough would otherwise grow this without bound; only a
        // few days are ever mounted, so throwing the lot away costs one rebuild.
        if cache.count > 60 { cache.removeAll(keepingCapacity: true) }
        let built = view.buildMarks()
        cache[key] = built
        return built
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

    private func buildMarks() -> [Mark] {
        guard budget > 0, !hours.isEmpty else { return [] }
        let byHour = Dictionary(uniqueKeysWithValues: hours.map { ($0.hour, $0) })
        var result: [Mark] = []

        // Which hours could carry a mark at all, worked out BEFORE any are
        // placed. Sampling the whole day and then rejecting is what made birds
        // vanish: with three candidates spread over twenty-four hours and only
        // a handful of them clear, most days drew none at all.
        let eligible = hours.filter { entry in
            let elevation = day.normalizedElevation(atHour: Double(entry.hour) + 0.5)
            let night = (1 - elevation * 6).clamped(to: 0...1)
            return drawsStars
                ? night > 0.25
                : night < 0.75 && isClear(entry)
        }.map(\.hour)
        guard !eligible.isEmpty else { return [] }

        // A flock shares one hour, so it reads as a group rather than a spread.
        let anchor = eligible[Int(SkyMarks.jitter(daySeed &+ deck.saltBase, 31)
                                  * Double(eligible.count)) % eligible.count]

        for index in 0..<budget {
            let salt = index &* 5_701
            let roll = SkyMarks.jitter(daySeed &+ deck.saltBase, salt)
            let hour: Double

            switch variant {
            case .field:
                let pick = eligible[Int(roll * Double(eligible.count)) % eligible.count]
                hour = Double(pick) + SkyMarks.jitter(daySeed &+ deck.saltBase, salt &+ 7)
            case .flock:
                hour = Double(anchor) + (roll - 0.5) * 2.4
            case .arcbound:
                // Weighted toward the eligible hours nearest solar noon, so the
                // sky thickens where the arc is highest.
                let sorted = eligible.sorted { abs($0 - 12) < abs($1 - 12) }
                let pull = SkyMarks.jitter(daySeed &+ deck.saltBase, salt &+ 17)
                let bias = roll * roll * (0.4 + pull * 0.6)
                let pick = sorted[min(Int(bias * Double(sorted.count)), sorted.count - 1)]
                hour = Double(pick) + SkyMarks.jitter(daySeed &+ deck.saltBase, salt &+ 7)
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

    /// Full or half, never in between. Each star keeps its own period and phase
    /// against the scrub, so passing sky winks rather than strobes. Dimming
    /// rather than disappearing keeps the field's shape while it does it: a
    /// star that vanishes takes a piece of the sky's arrangement with it.
    private func star(_ mark: Mark, in context: inout GraphicsContext) {
        let period = 3 + Int(SkyMarks.jitter(daySeed, mark.salt &+ 601) * 5)
        let offset = Int(SkyMarks.jitter(daySeed, mark.salt &+ 809) * Double(period))
        let dimmed = (blinkStep &+ offset) % period == 0

        let radius: CGFloat = 2.4
        var path = Path()
        path.move(to: CGPoint(x: mark.point.x - radius, y: mark.point.y))
        path.addQuadCurve(to: CGPoint(x: mark.point.x, y: mark.point.y - radius), control: mark.point)
        path.addQuadCurve(to: CGPoint(x: mark.point.x + radius, y: mark.point.y), control: mark.point)
        path.addQuadCurve(to: CGPoint(x: mark.point.x, y: mark.point.y + radius), control: mark.point)
        path.addQuadCurve(to: CGPoint(x: mark.point.x - radius, y: mark.point.y), control: mark.point)
        context.fill(path, with: .color(
            Theme.ink.opacity(SkyMarks.inkOpacity * mark.opacity * (dimmed ? 0.5 : 1))))
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
