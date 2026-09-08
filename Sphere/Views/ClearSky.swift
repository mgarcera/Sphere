import SwiftUI

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
    /// Marks above the horizon lighten as the sky darkens, so a cloud keeps its
    /// weight against whatever it is sitting on.
    var skyInk: Color = Theme.ink
    /// What sits BEHIND the marks, which is what a cloud fills with to occlude
    /// the deck behind it.
    var skyGround: Color = Theme.background

    /// The scrub position, quantised. Everything else in this app moves because
    /// the wheel moved, and a clock ticking on its own was the one thing that
    /// did not — it also meant nine views redrawing while nothing was happening.
    /// Stars wink as the sky passes instead, so an idle screen is perfectly
    /// still and the cost is bounded by how fast a thumb can turn.
    let blinkStep: Int

    private var drawsStars: Bool { deck == .high }

    /// Marks per eligible hour, not per day. A budget spread over a whole day
    /// put the same three birds into a two-hour clearing and a fourteen-hour
    /// one, so density on screen depended on how much of that day happened to
    /// be clear. The window is three hours wide and that is the only unit
    /// anyone experiences, so the rate is set against it.
    private var perDayCap: Int { drawsStars ? 26 : 12 }

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
        // The SAME box the decks use. A canvas sized to the arc alone cut off
        // everything the gutter is there to hold, and since these marks are
        // placed in the arc's coordinate space that meant the low ones simply
        // vanished.
        .frame(width: width, height: ArcGeometry.totalHeight(height), alignment: .topLeading)
        .allowsHitTesting(false)
    }

    /// Birds hold still, so their decks ignore the scrub entirely and never
    /// redraw while the wheel turns.
    static func == (a: ClearSky, b: ClearSky) -> Bool {
        a.daySeed == b.daySeed && a.deck == b.deck
            && a.width == b.width && a.height == b.height && a.hours == b.hours
            && (!a.drawsStars || a.blinkStep == b.blinkStep)
    }

    // MARK: - Cache

    private struct Key: Hashable {
        let daySeed: Int
        let deck: SkyContinuous.Deck
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

        let key = Key(daySeed: view.daySeed, deck: view.deck,
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
        guard !hours.isEmpty else { return [] }

        // Which hours could carry a mark at all, worked out before any are
        // placed. Sampling the whole day and rejecting afterwards is what made
        // birds vanish on days with only a few clear hours.
        let eligible = hours.filter { entry in
            let night = nightness(at: Double(entry.hour) + 0.5)
            return drawsStars
                ? night > 0.25 && deck.coverage(entry) < SkyHour.layerThreshold * 1.6
                : night < 0.75 && isClear(entry)
        }
        guard !eligible.isEmpty else { return [] }

        var result: [Mark] = []

        for entry in eligible {
            let hour = Double(entry.hour)
            // Salted from the HOUR, never from a running counter. A counter
            // that only advanced when a mark was placed handed every hour the
            // same roll once one came up empty, so a day that opened with no
            // birds could never draw one. Stars hid it by always placing at
            // least one.
            let count = drawsStars ? starCount(at: entry) : birdCount(at: entry)

            for index in 0..<count {
                let salt = entry.hour &* 5_701 &+ index &* 131
                let within = SkyMarks.jitter(daySeed &+ deck.saltBase, salt)
                let placed = hour + 0.5 + (within - 0.5)
                                + Double(index) * (drawsStars ? 0 : 0.18)

                guard placed >= 0, placed < 24 else { continue }

                let night = nightness(at: placed)
                let presence = drawsStars ? night : 1 - night
                guard presence > 0.25 else { continue }

                let spread = SkyMarks.jitter(daySeed &+ deck.saltBase, salt &+ 41)
                let out = deck.offset + CGFloat(spread - 0.5) * (drawsStars ? 30 : 16)

                result.append(Mark(point: point(hour: placed, out: out),
                                   opacity: presence,
                                   salt: salt))
                if result.count >= perDayCap { return result }
            }
        }
        return result
    }

    /// Held constant across the study, so only the birds are being compared.
    private func starCount(at entry: SkyHour) -> Int {
        let roll = SkyMarks.jitter(daySeed &+ deck.saltBase, entry.hour &* 977 &+ 211)
        return roll < 0.55 ? 2 : 1
    }

    /// One bird every two or three clear hours, evenly. A rate per hour rather
    /// than a budget per day: a budget put the same few birds into a two-hour
    /// clearing and a fourteen-hour one, so how dense they looked on screen
    /// depended on what fraction of the day happened to be clear. The window is
    /// three hours wide and that is the only unit anyone experiences.
    ///
    /// Grouping them and weighting them toward dawn and dusk were both tried
    /// against this. Even spacing won: a clearing you scroll into should have
    /// birds in it, not a chance of birds.
    private func birdCount(at entry: SkyHour) -> Int {
        SkyMarks.jitter(daySeed &+ deck.saltBase, entry.hour &* 977 &+ 211) < 0.42 ? 1 : 0
    }

    /// Night and day are one crossfade, not a switch: the arc pans through dusk
    /// under the thumb, so this has to be continuous.
    private func nightness(at hour: Double) -> Double {
        (1 - day.normalizedElevation(atHour: hour) * 6).clamped(to: 0...1)
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
            skyInk.opacity(SkyMarks.inkOpacity * mark.opacity * (dimmed ? 0.5 : 1))))
    }

    /// Two strokes meeting, the way a bird reads at this size.
    ///
    /// Each is caught at a different point in a wingbeat. Two numbers make the
    /// stage: how far the tips have dropped below the body, and how deeply the
    /// wing bows above it. Early in the beat the tips are near level and the
    /// bow is deep, which is the sharp indent; late in it the tips hang and the
    /// wing is almost straight. They move opposite each other, so no bird ever
    /// comes out as a flat tick.
    private func bird(_ mark: Mark, in context: inout GraphicsContext) {
        let stage = CGFloat(SkyMarks.jitter(daySeed, mark.salt &+ 1_301))
        let lean = CGFloat(SkyMarks.jitter(daySeed, mark.salt &+ 907) - 0.5) * 0.7
        let wing = 4.4 + CGFloat(SkyMarks.jitter(daySeed, mark.salt &+ 1_607)) * 1.8
        let drop = wing * (0.05 + stage * 0.8)
        let bow = wing * (0.62 - stage * 0.5)

        let centre = mark.point
        var path = Path()
        path.move(to: CGPoint(x: centre.x - wing, y: centre.y + drop - wing * lean))
        path.addQuadCurve(to: centre,
                          control: CGPoint(x: centre.x - wing * 0.5, y: centre.y - bow))
        path.addQuadCurve(to: CGPoint(x: centre.x + wing, y: centre.y + drop + wing * lean),
                          control: CGPoint(x: centre.x + wing * 0.5, y: centre.y - bow))
        context.stroke(path, with: .color(skyInk.opacity(SkyMarks.inkOpacity * mark.opacity)),
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
