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
struct SkyContinuous: View, Equatable {
    let day: SolarDay
    let width: CGFloat
    let height: CGFloat
    let hours: [SkyHour]
    let daySeed: Int
    /// One deck per view, so the three can be panned at three rates.
    let deck: Deck
    /// How far out the decks stand and how big a lobe is. The app's numbers are
    /// tuned for a day spread over eight screens; a widget holds the same day in
    /// one and needs its own.
    var scale: SkyScale = .app
    /// The box the curve sits in, which the sky has to agree with or it floats
    /// off its own arc.
    var geometry: ArcGeometry = .app

    var body: some View {
        Canvas { context, _ in
            let ink = GraphicsContext.Shading.color(Theme.ink.opacity(SkyMarks.inkOpacity))
            let ground = GraphicsContext.Shading.color(Theme.background)
            let faint = GraphicsContext.Shading.color(Theme.ink.opacity(SkyMarks.inkOpacity * 0.5))
            let byHour = Dictionary(uniqueKeysWithValues: hours.map { ($0.hour, $0) })
            let stormHours = Set(hours.filter(\.isConvective).map(\.hour))

            // Rain hangs below every deck, so it belongs with the nearest one.
            if deck == .low {
                for run in runs(byHour, where: { $0.condition.isWet }) {
                    let fall = curtain(run, byHour: byHour)
                    context.stroke(fall.far, with: faint,
                                   style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
                    context.stroke(fall.near, with: ink, style: scale.stroke)
                }
            }

            for run in runs(byHour, where: { deck.coverage($0) >= SkyHour.layerThreshold
                                             && !stormHours.contains($0.hour) }) {
                let path = lobedSilhouette(run, deck: deck, byHour: byHour)
                context.fill(path, with: ground)
                context.stroke(path, with: ink, style: scale.stroke)
            }

            // A storm is this same deck with much bigger lobes and coverage
            // forced full, so all three always draw.
            for run in runs(byHour, where: { $0.isConvective }) {
                let path = stormLayer(run, deck: deck)
                context.fill(path, with: ground)
                context.stroke(path, with: ink, style: scale.stroke)
            }

            if deck == .low {
                for entry in hours where entry.hasLightning {
                    context.stroke(strike(at: entry), with: ink, style: scale.stroke)
                }
                for run in runs(byHour, where: { $0.condition == .fog }) {
                    context.stroke(fog(run), with: ink, style: scale.stroke)
                }
            }
        }
        .frame(width: width, height: geometry.totalHeight(height), alignment: .topLeading)
    }

    /// Where the band sits and which way it leans, from the curve this layer
    /// belongs to. It used to live in ArcContent; it moved here so this view
    /// owns everything it needs and can be compared for equality.
    private func placement(_ hour: Double) -> (point: CGPoint, angle: Double) {
        let delta = 0.35
        func x(_ h: Double) -> CGFloat { width * (h / 24) }
        func y(_ h: Double) -> CGFloat {
            geometry.y(normalized: day.normalizedElevation(atHour: h), height: height)
        }
        let angle = atan2(y(hour + delta) - y(hour - delta), x(hour + delta) - x(hour - delta))
        return (CGPoint(x: x(hour), y: y(hour)), angle)
    }

    // MARK: - Decks

    enum Deck: CaseIterable, Identifiable {
        /// Declaration order is draw order: furthest first, so the nearer
        /// layers cut into them.
        case high, mid, low

        var id: Self { self }

        /// How fast this layer moves relative to the arc. The arc is the
        /// reference at 1, so nothing on the line ever drifts and only the
        /// upper sky recedes.
        var parallax: CGFloat {
            switch self {
            case .high: 0.85
            case .mid: 0.93
            case .low: 1.0
            }
        }

        func offset(_ scale: SkyScale) -> CGFloat {
            switch self {
            case .high: scale.highOffset
            case .mid: scale.midOffset
            case .low: scale.lowOffset
            }
        }

        /// How tall the lobes get at full coverage. Bulkier than the deck
        /// spacing in places, deliberately: a low cloud passing in front of a
        /// mid one is what the background fill is there to handle.
        func amplitude(_ scale: SkyScale) -> CGFloat {
            switch self {
            case .high: 7 * scale.amplitude
            case .mid: 10 * scale.amplitude
            case .low: 14 * scale.amplitude
            }
        }

        /// Lobe size for a storm: the same three positions, roughly doubled,
        /// which is what makes a storm read as heavy rather than as tall.
        func stormAmplitude(_ scale: SkyScale) -> CGFloat {
            switch self {
            case .high: 14 * scale.amplitude
            case .mid: 20 * scale.amplitude
            case .low: 28 * scale.amplitude
            }
        }

        /// Without this every deck over the same run drew the identical
        /// outline, since the salt was built from the run alone.
        var saltBase: Int {
            switch self {
            case .high: 0
            case .mid: 5_003
            case .low: 9_973
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
    /// Five things separate a cloud from a mountain range, and the first draft
    /// had it on the wrong side of all of them.
    ///
    /// The lobe profile is a SEMICIRCLE, not a sine. A sine leaves gentle
    /// flanks rising to a point, which is a peak; a semicircle rises steeply at
    /// the sides and flattens on top, which is a puff.
    ///
    /// Each lobe is emitted as SMOOTH CURVES through its samples rather than
    /// straight segments. Nine line segments over a leaning bump is a ridge no
    /// matter what the profile says.
    ///
    /// The PLINTH carries most of the body. Mountains are peaks rising from a
    /// plain; a cloud is a mass with bumps on it, so the flat part under the
    /// lobes is now over half the deck's amplitude rather than under a third.
    ///
    /// The lean is much SHALLOWER, because a leaning pointed lobe is a
    /// mountain flank, and the second octave is much QUIETER, because that is
    /// where the serration was coming from.
    private func lobedSilhouette(_ run: ClosedRange<Int>, deck: Deck, byHour: [Int: SkyHour]) -> Path {
        scallopedMass(
            from: Double(run.lowerBound), to: Double(run.upperBound) + 1,
            baseOut: deck.offset(scale),
            plinth: deck.amplitude(scale) * 0.78,
            peakAmplitude: deck.amplitude(scale),
            lobeHours: scale.lobeHours,
            salt: deck.saltBase &+ run.lowerBound &* 31,
            coverage: { hour in self.reading(byHour, at: hour).map { deck.coverage($0) } ?? 0 }
        )
    }

    /// A flat-bottomed body with a scalloped top. Decks and storms are the same
    /// shape at different scales, which is what keeps them looking like one
    /// drawing.
    private func scallopedMass(from: Double, to: Double, baseOut: CGFloat,
                               plinth: CGFloat, peakAmplitude: CGFloat,
                               lobeHours: Double, salt saltBase: Int,
                               coverage: (Double) -> Double) -> Path {

        // A cloud that stops on a vertical edge reads as cut off. Both ends
        // now round from the base up to the lobe line over a short shoulder.
        let shoulder = min(0.16, (to - from) * 0.18)

        var path = Path()
        path.move(to: point(hour: from, out: baseOut))
        appendSmooth((1...4).map { step in
            let t = Double(step) / 4
            return point(hour: from + shoulder * t,
                         out: baseOut + plinth * CGFloat(sin(.pi / 2 * t)))
        }, to: &path)

        // The spans are worked out up front and normalised to fill the width
        // exactly. Advancing lobe by lobe and clamping the last one to whatever
        // was left over let it end up almost zero wide while still rising to
        // full height, which drew a needle sticking out of the cloud.
        let available = (to - shoulder) - (from + shoulder)
        guard available > 0 else { return path }
        let lobeCount = max(1, Int((available / lobeHours).rounded()))
        let widthRolls = (0..<lobeCount).map { SkyMarks.jitter(daySeed, saltBase &+ $0) }
        let widthTotal = widthRolls.reduce(0) { $0 + 0.55 + $1 }
        let spans = widthRolls.map { available * (0.55 + $0) / widthTotal }

        var hour = from + shoulder
        for index in 0..<lobeCount {
            let salt = saltBase &+ index
            let heightRoll = SkyMarks.jitter(daySeed, salt &+ 911)
            let skewRoll = SkyMarks.jitter(daySeed, salt &+ 1_733)
            let microRoll = SkyMarks.jitter(daySeed, salt &+ 2_591)

            let span = spans[index]
            let cover = coverage(hour + span / 2)
            let peak = peakAmplitude * CGFloat(0.28 + cover * 0.42) * CGFloat(0.8 + heightRoll * 0.5)
            // Barely off centre. Any more and the lobe becomes a slope.
            let skew = 0.42 + 0.16 * skewRoll
            let microAmp = peak * 0.09

            var crest: [CGPoint] = [point(hour: hour, out: baseOut + plinth)]
            let steps = 12
            for step in 1...steps {
                let t = Double(step) / Double(steps)
                let warped = t < skew ? 0.5 * t / skew : 0.5 + 0.5 * (t - skew) / (1 - skew)
                // Semicircular, so the sides stand up and the top is round.
                let big = peak * CGFloat(sqrt(max(0, 1 - pow(2 * warped - 1, 2))))
                let micro = microAmp * CGFloat(sin(.pi * 2 * t + microRoll * 6.28)) * CGFloat(sin(.pi * t))
                crest.append(point(hour: hour + span * t, out: baseOut + plinth + big + micro))
            }

            // Smooth within the lobe; the join to the next one stays a cusp,
            // which is the scallop.
            appendSmooth(crest, to: &path)

            hour += span
        }

        appendSmooth((1...4).map { step in
            let t = Double(step) / 4
            return point(hour: to - shoulder + shoulder * t,
                         out: baseOut + plinth * CGFloat(cos(.pi / 2 * t)))
        }, to: &path)

        let backSteps = max(4, Int((to - from) * 4))
        for step in stride(from: backSteps, through: 0, by: -1) {
            let h = from + (to - from) * Double(step) / Double(backSteps)
            path.addLine(to: point(hour: h, out: baseOut))
        }
        path.closeSubpath()
        return path
    }

    /// Quadratic curves through the midpoints of a polyline, which rounds the
    /// samples without pulling the outline off them.
    private func appendSmooth(_ points: [CGPoint], to path: inout Path) {
        guard points.count > 2 else {
            points.forEach { path.addLine(to: $0) }
            return
        }
        path.addLine(to: points[0])
        for index in 1..<(points.count - 1) {
            let mid = CGPoint(
                x: (points[index].x + points[index + 1].x) / 2,
                y: (points[index].y + points[index + 1].y) / 2
            )
            path.addQuadCurve(to: mid, control: points[index])
        }
        path.addQuadCurve(to: points[points.count - 1], control: points[points.count - 2])
    }

    /// One layer of a storm: the same construction as an ordinary deck, at the
    /// same height, with lobes about twice the size and coverage forced to
    /// full. Three of these stacked and cutting into each other is the storm.
    private func stormLayer(_ run: ClosedRange<Int>, deck: Deck) -> Path {
        scallopedMass(
            from: Double(run.lowerBound), to: Double(run.upperBound) + 1,
            baseOut: deck.offset(scale),
            plinth: deck.stormAmplitude(scale) * 0.78,
            peakAmplitude: deck.stormAmplitude(scale),
            lobeHours: scale.lobeHours,
            salt: deck.saltBase &+ run.lowerBound &* 31 &+ 4_099,
            coverage: { _ in 1 }
        )
    }

    /// Rain as a curtain between the cloud base and the arc.
    ///
    /// Everything about a single stroke varies: where it starts along the
    /// hour, how far up under the cloud it begins, how long it is, and how far
    /// the wind lays it over. The first version fixed all four, which put every
    /// streak on a ruled line at the same length, and that is what read as
    /// uniform. Open-Meteo also quantises precipitation coarsely, so hour after
    /// hour reports the same 0.4mm and intensity alone varies almost nothing.
    ///
    /// Drizzle and rain differ in kind rather than degree: drizzle is dense,
    /// short and nearly upright, rain is sparser, longer and leaning.
    private func curtain(_ run: ClosedRange<Int>, byHour: [Int: SkyHour]) -> (near: Path, far: Path) {
        var near = Path()
        var far = Path()
        let base = scale.lowOffset - 4 * scale.amplitude

        for hour in run {
            guard let entry = byHour[hour] else { continue }
            let intensity = min(entry.precipitation / 3, 1)
            let fine = entry.condition == .drizzle
            let count = max(3, Int(((fine ? 6 : 3) + intensity * (fine ? 5 : 6)).rounded()))
            let reach = CGFloat((fine ? 4 : 7) + intensity * (fine ? 6 : 15))
            let windLean = CGFloat(min(entry.wind / 45, 1)) * (fine ? 0.07 : 0.20)

            for index in 0..<count {
                let salt = hour &* 101 &+ index
                let jx = SkyMarks.jitter(daySeed, salt)
                let jy = SkyMarks.jitter(daySeed, salt &+ 7_717)
                let jl = SkyMarks.jitter(daySeed, salt &+ 3_301)
                let jlean = SkyMarks.jitter(daySeed, salt &+ 5_501)

                let at = Double(hour) + (Double(index) + 0.1 + 0.8 * jx) / Double(count)

                if entry.condition.isFrozen {
                    let size = CGFloat(1.4 + jl * 2.2)
                    let centre = point(hour: at, out: base - CGFloat(jy) * reach)
                    for k in 0..<3 {
                        let angle = Double(k) * .pi / 3
                        far.move(to: CGPoint(x: centre.x - size * cos(angle), y: centre.y - size * sin(angle)))
                        far.addLine(to: CGPoint(x: centre.x + size * cos(angle), y: centre.y + size * sin(angle)))
                    }
                    continue
                }

                // Stagger the start so the top edge is not a rule.
                let start = base - CGFloat(jy) * 8
                let length = reach * CGFloat(0.5 + jl * 1.0)
                let lean = windLean * (0.55 + jlean * 0.9)

                // Half the streaks fall to the lighter pass, which reads as
                // distance.
                let isNear = jx + jl > 1.0
                if isNear {
                    near.move(to: point(hour: at, out: start))
                    near.addLine(to: point(hour: at + lean, out: start - length))
                } else {
                    far.move(to: point(hour: at, out: start))
                    far.addLine(to: point(hour: at + lean * 0.8, out: start - length * 0.7))
                }
            }
        }
        return (near, far)
    }

    /// One or two strikes per storm hour, placed and shaped from the hour's
    /// own seed so no two are the same bolt in the same spot.
    private func strike(at entry: SkyHour) -> Path {
        var path = Path()
        let count = SkyMarks.jitter(daySeed, entry.hour &* 137) > 0.55 ? 2 : 1

        for index in 0..<count {
            let salt = entry.hour &* 211 &+ index
            let at = Double(entry.hour) + 0.25 + 0.5 * SkyMarks.jitter(daySeed, salt)
            let height = CGFloat(13 + SkyMarks.jitter(daySeed, salt &+ 41) * 10)
            let anchor = point(hour: at, out: scale.lowOffset - 6 * scale.amplitude)
            let base = placement(at)
            var transform = CGAffineTransform(translationX: anchor.x, y: anchor.y)
            transform = transform.rotated(by: base.angle)
            path.addPath(SkyMarks.bolt(height: height, seed: daySeed, salt: salt).applying(transform))
        }
        return path
    }

    private func fog(_ run: ClosedRange<Int>) -> Path {
        var path = Path()
        for hour in run {
            let anchor = point(hour: Double(hour) + 0.5, out: scale.lowOffset - 12 * scale.amplitude)
            let base = placement(Double(hour) + 0.5)
            var transform = CGAffineTransform(translationX: anchor.x, y: anchor.y)
            transform = transform.rotated(by: base.angle)
            path.addPath(SkyMarks.fogLines(width: 26).applying(transform))
        }
        return path
    }
}
