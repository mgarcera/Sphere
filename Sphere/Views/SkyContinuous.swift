import SwiftUI

/// Style B. One silhouette per deck running the whole day, rather than a mark
/// per hour. Coverage drives how far the outline bulges and where it breaks, so
/// the sky is a single drawn thing and there are no repeated glyphs at all.
///
/// The trade is legibility: you can see the shape of the day's weather at a
/// glance but not read off what happens at three o'clock.
struct SkyContinuous: View {
    let hours: [SkyHour]
    let daySeed: Int
    let placement: (Double) -> (point: CGPoint, angle: Double)

    var body: some View {
        Canvas { context, _ in
            let ink = GraphicsContext.Shading.color(Theme.ink.opacity(0.55))
            let byHour = Dictionary(uniqueKeysWithValues: hours.map { ($0.hour, $0) })

            for deck in Deck.allCases {
                for run in runs(in: byHour, deck: deck) {
                    context.stroke(silhouette(run, deck: deck, byHour: byHour),
                                   with: ink, style: SkyMarks.stroke)
                }
            }

            // The body only appears where nothing has closed over it.
            for entry in hours where entry.cloudLow < 0.25 && entry.cloudMid < 0.35 {
                let base = placement(Double(entry.hour) + 0.5)
                let position = CGPoint(
                    x: base.point.x + sin(base.angle) * SkyMarks.bodyOffset,
                    y: base.point.y - cos(base.angle) * SkyMarks.bodyOffset
                )
                var transform = CGAffineTransform(translationX: position.x, y: position.y)
                transform = transform.rotated(by: base.angle)
                let body = entry.isDaylight ? SkyMarks.sun(radius: 3.6) : SkyMarks.crescent(radius: 4.2)
                context.stroke(body.applying(transform), with: ink, style: SkyMarks.stroke)
            }

            for entry in hours where entry.condition.isWet {
                let base = placement(Double(entry.hour) + 0.5)
                let position = CGPoint(
                    x: base.point.x + sin(base.angle) * (SkyMarks.lowOffset - 12),
                    y: base.point.y - cos(base.angle) * (SkyMarks.lowOffset - 12)
                )
                var transform = CGAffineTransform(translationX: position.x, y: position.y)
                transform = transform.rotated(by: base.angle)
                let fall = SkyMarks.precipitation(entry.precipitation,
                                                  frozen: entry.condition.isFrozen,
                                                  seed: daySeed, salt: entry.hour &* 11,
                                                  width: 22)
                context.stroke(fall.applying(transform), with: ink, style: SkyMarks.stroke)
            }
        }
    }

    private enum Deck: CaseIterable {
        case high, mid, low

        var offset: CGFloat {
            switch self {
            case .high: SkyMarks.highOffset
            case .mid: SkyMarks.midOffset
            case .low: SkyMarks.lowOffset
            }
        }

        var amplitude: CGFloat {
            switch self {
            case .high: 3
            case .mid: 5
            case .low: 8
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

    /// Unbroken stretches where this deck is present. A gap in coverage is a
    /// gap in the silhouette, which is what makes a clearing read as one.
    private func runs(in byHour: [Int: SkyHour], deck: Deck) -> [[Int]] {
        var result: [[Int]] = []
        var current: [Int] = []
        for hour in 0..<24 {
            let present = byHour[hour].map { deck.coverage($0) >= SkyHour.layerThreshold } ?? false
            if present {
                current.append(hour)
            } else if !current.isEmpty {
                result.append(current)
                current = []
            }
        }
        if !current.isEmpty { result.append(current) }
        return result.filter { $0.count >= 1 }
    }

    private func silhouette(_ run: [Int], deck: Deck, byHour: [Int: SkyHour]) -> Path {
        var path = Path()
        guard let first = run.first, let last = run.last else { return path }

        // Sample finer than hourly so the outline is a curve, not a zigzag.
        let steps = max(4, (last - first + 1) * 4)
        var points: [CGPoint] = []

        for step in 0...steps {
            let hour = Double(first) + Double(last - first + 1) * Double(step) / Double(steps)
            let sample = byHour[min(max(Int(hour), 0), 23)]
            let coverage = sample.map { deck.coverage($0) } ?? 0
            let wobble = SkyMarks.jitter(daySeed, Int(hour * 4) &+ deck.amplitude.hashValue) - 0.5
            let bulge = deck.amplitude * CGFloat(0.35 + coverage) * CGFloat(1 + wobble * 0.5)

            let base = placement(hour)
            let out = deck.offset + bulge
            points.append(CGPoint(
                x: base.point.x + sin(base.angle) * out,
                y: base.point.y - cos(base.angle) * out
            ))
        }

        path.addLines(points)
        return path
    }
}
