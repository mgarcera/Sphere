import SwiftUI

/// A three-hour slice of an unbounded timeline. The dot is nailed to the centre
/// of the screen and never moves; three days of arc slide underneath it, so
/// crossing midnight needs no separate control and no seam.
struct ArcWindow: View {
    let model: DayModel
    /// Every capsule is held back while a jump is in flight, not just the
    /// destination: the others sweep across the screen too, and that is most
    /// of what a long jump looks like.
    var eventsHidden = false
    var arcHeight: CGFloat = 190
    /// How dark the sky is: the night's own strength, and what the marks above
    /// the horizon lighten with.
    var nightness: Double = 0
    /// Weather takes precedence over night, the way it does over dusk.
    var nightSuppressedBy: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let pointsPerHour = proxy.size.width / DayModel.windowHours
            let dayWidth = 24 * pointsPerHour
            let firstDay = model.dayIndex - 1
            let originHour = Double(firstDay) * 24
            let centreX = proxy.size.width / 2
            let pan = centreX - (model.focusHour - originHour) * pointsPerHour
            let dotY = ArcGeometry.y(normalized: model.normalizedElevation(atAbsoluteHour: model.focusHour), height: arcHeight)

            ZStack(alignment: .topLeading) {
                // The clip moved off this stack and onto the two groups that
                // actually pan, so the night between them can reach above the
                // block and cover the header's sky as well.
                ZStack(alignment: .topLeading) {
                // Each day is its own cached layer, so only the set of three
                // changes when the wheel crosses a boundary. Panning never
                // re-samples a path.
                HStack(alignment: .top, spacing: 0) {
                    ForEach(firstDay...(firstDay + 2), id: \.self) { index in
                        ArcContent(day: model.solarDay(index), width: dayWidth, height: arcHeight)
                            .equatable()
                    }
                }
                .frame(width: dayWidth * 3, alignment: .topLeading)
                .offset(x: pan)
                }
                .frame(width: proxy.size.width, height: ArcGeometry.totalHeight(arcHeight),
                       alignment: .topLeading)
                .clipped()

                // Over the curve, the ticks and the labels; under the sky. The
                // fill's edge IS the curve, so covering the line it is drawn
                // from is what makes it read as an edge of the world rather
                // than a shape laid over one.
                if nightness > 0 {
                    NightSky(nightness: nightness,
                             arcHeight: arcHeight,
                             focusHour: model.focusHour,
                             normalizedElevation: { model.normalizedElevation(atAbsoluteHour: $0) },
                             suppressedBy: nightSuppressedBy)
                        .frame(width: proxy.size.width,
                               height: NightSky.reach + ArcGeometry.totalHeight(arcHeight))
                        .offset(y: -NightSky.reach)
                }

                ZStack(alignment: .topLeading) {
                // Each deck is its own layer so it can trail the arc by its own
                // amount. Further decks lag more, which is the parallax; they
                // catch up the moment the wheel stops, so a cloud is never
                // permanently off its hour.
                ForEach(SkyContinuous.Deck.allCases) { deck in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(firstDay...(firstDay + 2), id: \.self) { index in
                            ZStack(alignment: .topLeading) {
                                // Behind the deck's own drawing, so a cloud
                                // filling with the background covers what is
                                // meant to be behind it.
                                ClearSky(
                                    day: model.solarDay(index),
                                    width: dayWidth,
                                    height: arcHeight,
                                    hours: model.sky(forDayIndex: index),
                                    daySeed: index,
                                    deck: deck,
                                    skyInk: skyInk,
                                    skyGround: skyGround,
                                    blinkStep: Int(model.focusHour * 8)
                                )
                                .equatable()

                                SkyContinuous(
                                    day: model.solarDay(index),
                                    width: dayWidth,
                                    height: arcHeight,
                                    hours: model.sky(forDayIndex: index),
                                    daySeed: index,
                                    deck: deck,
                                    skyInk: skyInk,
                                    skyGround: skyGround
                                )
                                .equatable()
                            }
                            // Top-aligned and at the FULL height. Without the
                            // alignment this centred 322pt of sky in a 190pt
                            // box and pushed every deck 66pt up into the
                            // window's clip, which cut the tallest storms off.
                            .frame(width: dayWidth,
                                   height: ArcGeometry.totalHeight(arcHeight),
                                   alignment: .topLeading)
                        }
                    }
                    .frame(width: dayWidth * 3, alignment: .topLeading)
                    // Scaling horizontally about the dot is what makes this
                    // work. A plain slower offset drifts without bound: the
                    // error grows with distance from the layer's origin and
                    // runs to hundreds of points across a day. Scaled, the
                    // error is (1 - factor) x distance from the dot, so it is
                    // zero under the dot and at most about 29pt at the screen
                    // edge, whatever hour you are on.
                    //
                    // The 15% horizontal squash on the high deck comes free
                    // with it, and reads as distance rather than as a defect.
                    .scaleEffect(x: deck.parallax, y: 1, anchor: .leading)
                    .offset(x: pan * deck.parallax + centreX * (1 - deck.parallax))
                }

                EventLayer(
                    events: model.timedEvents,
                    originHour: originHour,
                    pointsPerHour: pointsPerHour,
                    width: dayWidth * 3,
                    height: arcHeight,
                    activeID: model.activeEvent?.id,
                    elevation: { model.normalizedElevation(atAbsoluteHour: $0) }
                )
                .offset(x: pan)
                .opacity(eventsHidden ? 0 : 1)

                Rectangle()
                    .fill(Theme.hairlineSoft)
                    .frame(width: 1, height: max(0, ArcGeometry.baseline(arcHeight) - dotY))
                    .position(x: centreX, y: (ArcGeometry.baseline(arcHeight) + dotY) / 2)

                TimeDot(
                    elevationDegrees: model.elevationDegrees(atAbsoluteHour: model.focusHour),
                    moon: model.focusMoonPhase,
                    ceilingDegrees: model.focusSolarDay.seasonalCeiling
                )
                .position(x: centreX, y: dotY)
                }
                .frame(width: proxy.size.width, height: ArcGeometry.totalHeight(arcHeight),
                       alignment: .topLeading)
                .clipped()
            }
            .frame(width: proxy.size.width, height: ArcGeometry.totalHeight(arcHeight), alignment: .topLeading)
        }
        .frame(height: ArcGeometry.totalHeight(arcHeight))
    }

    /// One pair for the whole window: it is three hours wide, so the difference
    /// between its edges is not worth redrawing three cached layers for.
    private var skyInk: Color { Theme.skyInk(nightness: nightness) }

    /// What a cloud fills with to cut a hole in the deck behind it — the sky's
    /// own colour, not the paper's, or the clouds punch white holes in a night.
    private var skyGround: Color {
        Theme.background.mix(with: NightSky.colour, by: nightness)
    }
}
