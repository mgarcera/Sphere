import SwiftUI

/// The atmosphere half of the app: one drawn sky running the length of the day,
/// above the arc, with the work and social spheres on the line below it.
///
/// Three things make these read as cloud rather than wind, and the first draft
/// had none of them. Each deck is a CLOSED body with a base and a scalloped
/// top, not an open curve. The scallops are convex lobes meeting at cusps, not
/// sine waves, because smooth undulation reads as fluid. And every deck is
/// filled with the background before it is stroked, so a nearer deck cuts a
/// hole in the one behind it: line art can still occlude, which is what gives
/// the band depth instead of leaving three parallel streaks.
struct SkyContinuous: View {
    let hours: [SkyHour]
    let daySeed: Int
    var shape: SkyShape = .lobed
    let placement: (Double) -> (point: CGPoint, angle: Double)

    /// Roughly a third of an hour per lobe, which is a cloud-sized bump at the
    /// three-hour zoom.
    private static let lobeHours = 0.34

    var body: some View {
        Canvas { context, _ in
            let ink = GraphicsContext.Shading.color(Theme.ink.opacity(SkyMarks.inkOpacity))
            let ground = GraphicsContext.Shading.color(Theme.background)
            let faint = GraphicsContext.Shading.color(Theme.ink.opacity(SkyMarks.inkOpacity * 0.5))
            let byHour = Dictionary(uniqueKeysWithValues: hours.map { ($0.hour, $0) })
            let stormHours = Set(hours.filter { $0.condition == .thunderstorm }.map(\.hour))

            // Rain first: it hangs between the cloud base and the arc, so the
            // decks are drawn over its top edge.
            for run in runs(byHour, where: { $0.condition.isWet }) {
                context.stroke(curtain(run, byHour: byHour), with: ink, style: SkyMarks.stroke)
            }

            // Far decks first so the near ones can occlude them.
            for deck in [Deck.high, .mid, .low] {
                for run in runs(byHour, where: { deck.coverage($0) >= SkyHour.layerThreshold
                                                 && !stormHours.contains($0.hour) }) {
                    switch shape {
                    case .lobed:
                        let path = lobedSilhouette(run, deck: deck, byHour: byHour)
                        context.fill(path, with: ground)
                        context.stroke(path, with: ink, style: SkyMarks.stroke)
                    case .circles:
                        drawCircleDeck(run, deck: deck, byHour: byHour,
                                       in: context, ink: ink, ground: ground)
                    }
                }
            }

            // A cumulonimbus is not a low cloud, it is a tower that starts low
            // and spreads an anvil at cirrus height, so a storm merges the
            // three decks into one form instead of stacking them.
            for run in runs(byHour, where: { $0.condition == .thunderstorm }) {
                let tower = cumulonimbus(run, byHour: byHour)
                context.fill(tower, with: ground)
                context.stroke(tower, with: ink, style: SkyMarks.heavyStroke)
            }

            for entry in hours where entry.condition == .thunderstorm {
                context.stroke(strike(at: entry), with: ink, style: SkyMarks.heavyStroke)
            }

            for run in runs(byHour, where: { $0.condition == .fog }) {
                context.stroke(fog(run), with: ink, style: SkyMarks.stroke)
            }

            // A clear hour in range still draws something, so that an empty
            // band always means "no data" and never "nothing in the sky".
            for run in runs(byHour, where: { $0.cloudLow < SkyHour.layerThreshold
                                             && $0.cloudMid < SkyHour.layerThreshold
                                             && $0.cloudHigh < SkyHour.layerThreshold
                                             && !$0.condition.isWet }) {
                context.stroke(wisp(run), with: faint, style: SkyMarks.stroke)
            }
        }
    }

    // MARK: - Decks

    private enum Deck {
        case high, mid, low

        var offset: CGFloat {
            switch self {
            case .high: SkyMarks.highOffset
            case .mid: SkyMarks.midOffset
            case .low: SkyMarks.lowOffset
            }
        }

        /// How tall the lobes get at full coverage.
        var amplitude: CGFloat {
            switch self {
            case .high: 4
            case .mid: 7
            case .low: 11
            }
        }

        func coverage(_ hour: SkyHour) -> Double {
            switch self {
            case .high: hour.cloudHigh
            case .mid: hour.cloudMid
            case .low: hour.cloudLow
            }
        }
    }

    // MARK: - Geometry

    private func point(hour: Double, out: CGFloat) -> CGPoint {
        let base = placement(hour)
        return CGPoint(
            x: base.point.x + sin(base.angle) * out,
            y: base.point.y - cos(base.angle) * out
        )
    }

    private func reading(_ byHour: [Int: SkyHour], at hour: Double) -> SkyHour? {
        byHour[min(max(Int(hour.rounded(.down)), 0), 23)]
    }

    /// Unbroken stretches matching a test. A gap is a gap in the drawing, which
    /// is what lets a clearing read as one.
    private func runs(_ byHour: [Int: SkyHour], where test: (SkyHour) -> Bool) -> [ClosedRange<Int>] {
        var result: [ClosedRange<Int>] = []
        var start: Int?
        for hour in 0..<24 {
            let matches = byHour[hour].map(test) ?? false
            if matches, start == nil { start = hour }
            if !matches, let from = start { result.append(from...(hour - 1)); start = nil }
        }
        if let from = start { result.append(from...23) }
        return result
    }

    /// A closed body, scalloped along the top and flat along the base.
    ///
    /// Three things keep it off a decorative border. Lobe WIDTH varies, not
    /// just height: uniform width is what read as a repeating pattern, more
    /// than uniform height ever did. Each lobe peaks off-centre so it leans.
    /// And a second, smaller octave rides the big lobes, because two scales of
    /// detail is most of what separates a cloud from a scallop.
    private func lobedSilhouette(_ run: ClosedRange<Int>, deck: Deck, byHour: [Int: SkyHour]) -> Path {
        let from = Double(run.lowerBound)
        let to = Double(run.upperBound) + 1
        let plinth = deck.amplitude * 0.3

        var path = Path()
        path.move(to: point(hour: from, out: deck.offset))

        var hour = from
        var index = 0
        while hour < to - 1e-6 {
            let salt = run.lowerBound &* 31 &+ index
            let widthRoll = SkyMarks.jitter(daySeed, salt)
            let heightRoll = SkyMarks.jitter(daySeed, salt &+ 911)
            let skewRoll = SkyMarks.jitter(daySeed, salt &+ 1_733)
            let microRoll = SkyMarks.jitter(daySeed, salt &+ 2_591)

            let span = min(Self.lobeHours * (0.5 + 1.1 * widthRoll), to - hour)
            let coverage = reading(byHour, at: hour + span / 2).map { deck.coverage($0) } ?? 0
            let peak = deck.amplitude * CGFloat(0.35 + coverage) * CGFloat(0.7 + heightRoll * 0.8)
            // Peak position inside the lobe: 0.5 is symmetric, away from it leans.
            let skew = 0.28 + 0.44 * skewRoll
            let microCycles = 2.0 + (microRoll * 2).rounded()
            let microAmp = peak * 0.22

            let steps = 9
            for step in 1...steps {
                let t = Double(step) / Double(steps)
                // Warp t so the crest lands at `skew` rather than the middle.
                let warped = t < skew ? 0.5 * t / skew : 0.5 + 0.5 * (t - skew) / (1 - skew)
                let big = peak * CGFloat(sin(.pi * warped))
                let micro = microAmp * CGFloat(sin(.pi * microCycles * t + microRoll * 6.28)) * CGFloat(sin(.pi * t))
                path.addLine(to: point(hour: hour + span * t, out: deck.offset + plinth + big + micro))
            }

            hour += span
            index += 1
        }

        path.addLine(to: point(hour: to, out: deck.offset))
        for step in stride(from: max(2, run.count * 3), through: 0, by: -1) {
            let h = from + (to - from) * Double(step) / Double(max(2, run.count * 3))
            path.addLine(to: point(hour: h, out: deck.offset))
        }
        path.closeSubpath()
        return path
    }

    /// The other construction: a run of overlapping circles of varying radius,
    /// the way a drawn cloud is actually built. The cusps fall out of the
    /// geometry instead of being jittered in.
    ///
    /// The outline is the union's boundary, drawn by filling the union in ink
    /// and then filling a shrunk copy in the background, which leaves a ring.
    /// Stroking the compound path directly would draw every interior arc.
    private func drawCircleDeck(_ run: ClosedRange<Int>, deck: Deck, byHour: [Int: SkyHour],
                                in context: GraphicsContext,
                                ink: GraphicsContext.Shading, ground: GraphicsContext.Shading) {
        let from = Double(run.lowerBound)
        let to = Double(run.upperBound) + 1
        let weight = SkyMarks.stroke.lineWidth

        var outer = Path()
        var inner = Path()
        var hour = from
        var index = 0

        while hour < to - 1e-6 {
            let salt = run.lowerBound &* 47 &+ index
            let radiusRoll = SkyMarks.jitter(daySeed, salt)
            let liftRoll = SkyMarks.jitter(daySeed, salt &+ 613)
            let coverage = reading(byHour, at: hour).map { deck.coverage($0) } ?? 0

            let radius = deck.amplitude * CGFloat(0.42 + coverage * 0.7) * CGFloat(0.6 + radiusRoll * 0.9)
            let lift = radius * CGFloat(0.35 + liftRoll * 0.45)
            let centre = point(hour: hour, out: deck.offset + lift)

            outer.addEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                                        width: radius * 2, height: radius * 2))
            let shrunk = max(radius - weight, 0.5)
            inner.addEllipse(in: CGRect(x: centre.x - shrunk, y: centre.y - shrunk,
                                        width: shrunk * 2, height: shrunk * 2))

            // Circles overlap by roughly half so the union stays continuous.
            hour += Self.lobeHours * (0.34 + 0.4 * radiusRoll)
            index += 1
        }

        // Clip to the sky side of the base, so the union gets a flat underside
        // rather than a row of bulges.
        context.drawLayer { layer in
            layer.clip(to: skySide(from: from - 0.6, to: to + 0.6, base: deck.offset))
            layer.fill(outer, with: ink, style: FillStyle(eoFill: false))
            layer.fill(inner, with: ground, style: FillStyle(eoFill: false))
        }

        var base = Path()
        let steps = max(2, run.count * 4)
        for step in 0...steps {
            let h = from + (to - from) * Double(step) / Double(steps)
            let position = point(hour: h, out: deck.offset)
            if step == 0 { base.move(to: position) } else { base.addLine(to: position) }
        }
        context.stroke(base, with: ink, style: SkyMarks.stroke)
    }

    /// Everything outward of the base line across an hour span.
    private func skySide(from: Double, to: Double, base: CGFloat) -> Path {
        var path = Path()
        let steps = max(4, Int((to - from) * 6))
        for step in 0...steps {
            let h = from + (to - from) * Double(step) / Double(steps)
            let position = point(hour: h, out: base)
            if step == 0 { path.move(to: position) } else { path.addLine(to: position) }
        }
        for step in stride(from: steps, through: 0, by: -1) {
            let h = from + (to - from) * Double(step) / Double(steps)
            path.addLine(to: point(hour: h, out: base + 140))
        }
        path.closeSubpath()
        return path
    }

    /// Base low, tower rising, anvil flaring flat at cirrus height.
    private func cumulonimbus(_ run: ClosedRange<Int>, byHour: [Int: SkyHour]) -> Path {
        let from = Double(run.lowerBound)
        let to = Double(run.upperBound) + 1
        let flare = min(0.45, (to - from) * 0.3)
        let top = SkyMarks.highOffset
        let shoulder = SkyMarks.midOffset

        var path = Path()
        path.move(to: point(hour: from, out: SkyMarks.lowOffset))
        path.addLine(to: point(hour: from + (to - from) * 0.1, out: shoulder))
        // Anvil overhangs the tower on both sides.
        path.addLine(to: point(hour: from - flare, out: top - 3))
        path.addLine(to: point(hour: from - flare * 0.6, out: top + 2))
        path.addLine(to: point(hour: to + flare * 0.6, out: top + 2))
        path.addLine(to: point(hour: to + flare, out: top - 3))
        path.addLine(to: point(hour: to - (to - from) * 0.1, out: shoulder))
        path.addLine(to: point(hour: to, out: SkyMarks.lowOffset))

        let backSteps = max(2, run.count * 3)
        for step in stride(from: backSteps, through: 0, by: -1) {
            let hour = from + (to - from) * Double(step) / Double(backSteps)
            path.addLine(to: point(hour: hour, out: SkyMarks.lowOffset))
        }
        path.closeSubpath()
        return path
    }

    /// Rain as a hatched curtain between the cloud base and the arc, leaned by
    /// the wind, with density and length from millimetres rather than from
    /// which side of a category boundary the hour landed on.
    private func curtain(_ run: ClosedRange<Int>, byHour: [Int: SkyHour]) -> Path {
        var path = Path()
        let top = SkyMarks.lowOffset - 4

        for hour in run {
            guard let entry = byHour[hour] else { continue }
            let intensity = min(entry.precipitation / 3, 1)
            let strokes = max(2, Int((3 + intensity * 5).rounded()))
            let drop = CGFloat(6 + intensity * 13)
            let lean = CGFloat(min(entry.wind / 45, 1)) * 0.16

            for index in 0..<strokes {
                let j = SkyMarks.jitter(daySeed, hour &* 101 &+ index)
                let at = Double(hour) + (Double(index) + 0.5) / Double(strokes) + (j - 0.5) * 0.06

                if entry.condition.isFrozen {
                    let c = point(hour: at, out: top - drop * 0.5)
                    let s: CGFloat = 2.2
                    for k in 0..<3 {
                        let angle = Double(k) * .pi / 3
                        path.move(to: CGPoint(x: c.x - s * cos(angle), y: c.y - s * sin(angle)))
                        path.addLine(to: CGPoint(x: c.x + s * cos(angle), y: c.y + s * sin(angle)))
                    }
                } else {
                    path.move(to: point(hour: at, out: top))
                    path.addLine(to: point(hour: at + lean, out: top - drop))
                }
            }
        }
        return path
    }

    private func strike(at entry: SkyHour) -> Path {
        let anchor = point(hour: Double(entry.hour) + 0.5, out: SkyMarks.lowOffset - 6)
        let base = placement(Double(entry.hour) + 0.5)
        var transform = CGAffineTransform(translationX: anchor.x, y: anchor.y)
        transform = transform.rotated(by: base.angle)
        return SkyMarks.bolt(height: 17).applying(transform)
    }

    private func fog(_ run: ClosedRange<Int>) -> Path {
        var path = Path()
        for hour in run {
            let anchor = point(hour: Double(hour) + 0.5, out: SkyMarks.lowOffset - 12)
            let base = placement(Double(hour) + 0.5)
            var transform = CGAffineTransform(translationX: anchor.x, y: anchor.y)
            transform = transform.rotated(by: base.angle)
            path.addPath(SkyMarks.fogLines(width: 26).applying(transform))
        }
        return path
    }

    /// One long thin stroke for an empty sky, so "clear" and "no data" never
    /// look the same.
    private func wisp(_ run: ClosedRange<Int>) -> Path {
        var path = Path()
        let from = Double(run.lowerBound) + 0.25
        let to = Double(run.upperBound) + 0.75
        let steps = max(3, run.count * 4)

        for step in 0...steps {
            let hour = from + (to - from) * Double(step) / Double(steps)
            let wobble = CGFloat(SkyMarks.jitter(daySeed, Int(hour * 3)) - 0.5) * 2
            let position = point(hour: hour, out: SkyMarks.highOffset + wobble)
            if step == 0 { path.move(to: position) } else { path.addLine(to: position) }
        }
        return path
    }
}
