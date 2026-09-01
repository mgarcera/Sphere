import SwiftUI

/// Style A. Each hour draws its own decks, at three heights above the arc.
/// Two overcast hours differ because their coverage, wind and rainfall differ,
/// and a day with cirrus above cumulus draws two bands rather than one glyph.
struct SkyLayered: View {
    let hours: [SkyHour]
    let daySeed: Int
    /// Point and tangent for an hour, from the arc that owns this band.
    let placement: (Double) -> (point: CGPoint, angle: Double)

    private static let cellWidth: CGFloat = 30

    var body: some View {
        Canvas { context, _ in
            let ink = GraphicsContext.Shading.color(Theme.ink.opacity(0.55))

            for entry in hours {
                let hour = Double(entry.hour) + 0.5
                let base = placement(hour)

                func draw(_ path: Path, offset: CGFloat, extraY: CGFloat = 0) {
                    let position = CGPoint(
                        x: base.point.x + sin(base.angle) * offset,
                        y: base.point.y - cos(base.angle) * offset + extraY
                    )
                    var transform = CGAffineTransform(translationX: position.x, y: position.y)
                    transform = transform.rotated(by: base.angle)
                    context.stroke(path.applying(transform), with: ink, style: SkyMarks.stroke)
                }

                // The body sits under the decks and hides when the low cloud
                // closes over it.
                if entry.bodyVisible {
                    if entry.isDaylight {
                        draw(SkyMarks.sun(radius: 3.6), offset: SkyMarks.bodyOffset)
                    } else {
                        draw(SkyMarks.crescent(radius: 4.2), offset: SkyMarks.bodyOffset)
                        if entry.cloudLow < 0.2 && entry.cloudMid < 0.2 {
                            draw(SkyMarks.stars(seed: daySeed, salt: entry.hour, spread: 22),
                                 offset: SkyMarks.bodyOffset)
                        }
                    }
                }

                if entry.hasHigh {
                    draw(SkyMarks.cirrus(coverage: entry.cloudHigh, wind: entry.wind,
                                         seed: daySeed, salt: entry.hour &* 3,
                                         baseWidth: Self.cellWidth),
                         offset: SkyMarks.highOffset)
                }

                if entry.hasMid {
                    draw(SkyMarks.cloud(coverage: entry.cloudMid, wind: entry.wind,
                                        seed: daySeed, salt: entry.hour &* 5,
                                        baseWidth: Self.cellWidth * 0.8, lobeHeight: 5),
                         offset: SkyMarks.midOffset)
                }

                if entry.hasLow {
                    draw(SkyMarks.cloud(coverage: entry.cloudLow, wind: entry.wind,
                                        seed: daySeed, salt: entry.hour &* 7,
                                        baseWidth: Self.cellWidth, lobeHeight: 7),
                         offset: SkyMarks.lowOffset)
                }

                if entry.condition == .fog {
                    draw(SkyMarks.fogLines(width: Self.cellWidth), offset: SkyMarks.lowOffset - 10)
                }

                if entry.condition.isWet {
                    draw(SkyMarks.precipitation(entry.precipitation,
                                                frozen: entry.condition.isFrozen,
                                                seed: daySeed, salt: entry.hour &* 11,
                                                width: Self.cellWidth * 0.7),
                         offset: SkyMarks.lowOffset - 12)
                }

                if entry.condition == .thunderstorm {
                    draw(SkyMarks.bolt(), offset: SkyMarks.lowOffset - 14)
                }
            }
        }
    }
}
