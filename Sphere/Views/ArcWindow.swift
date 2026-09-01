import SwiftUI

/// A three-hour slice of an unbounded timeline. The dot is nailed to the centre
/// of the screen and never moves; three days of arc slide underneath it, so
/// crossing midnight needs no separate control and no seam.
struct ArcWindow: View {
    let model: DayModel
    var arcHeight: CGFloat = 190

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

                // Each deck is its own layer so it can trail the arc by its own
                // amount. Further decks lag more, which is the parallax; they
                // catch up the moment the wheel stops, so a cloud is never
                // permanently off its hour.
                ForEach(SkyContinuous.Deck.allCases) { deck in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(firstDay...(firstDay + 2), id: \.self) { index in
                            SkyContinuous(
                                day: model.solarDay(index),
                                width: dayWidth,
                                height: arcHeight,
                                hours: model.sky(forDayIndex: index),
                                daySeed: index,
                                deck: deck
                            )
                            .equatable()
                        }
                    }
                    .frame(width: dayWidth * 3, alignment: .topLeading)
                    .offset(x: pan)
                    .animation(.interactiveSpring(response: deck.lag, dampingFraction: 1), value: pan)
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
            .frame(width: proxy.size.width, height: ArcGeometry.totalHeight(arcHeight), alignment: .topLeading)
            .clipped()
        }
        .frame(height: ArcGeometry.totalHeight(arcHeight))
    }
}
