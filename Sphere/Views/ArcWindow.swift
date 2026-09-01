import SwiftUI

/// A three-hour slice of an unbounded timeline. The dot is nailed to the centre
/// of the screen and never moves; three days of arc slide underneath it, so
/// crossing midnight needs no separate control and no seam.
struct ArcWindow: View {
    let model: DayModel
    var arcHeight: CGFloat = 190
    /// Headroom above the curve's peak. The dot is 42pt across at full ray
    /// length, and at midsummer noon it sits on y = 0, so without this the rays
    /// are clipped exactly when they are longest.
    var topInset: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            let pointsPerHour = proxy.size.width / DayModel.windowHours
            let dayWidth = 24 * pointsPerHour
            let firstDay = model.dayIndex - 1
            let originHour = Double(firstDay) * 24
            let centreX = proxy.size.width / 2
            let pan = centreX - (model.focusHour - originHour) * pointsPerHour
            let dotY = topInset + ArcGeometry.y(normalized: model.normalizedElevation(atAbsoluteHour: model.focusHour), height: arcHeight)

            ZStack(alignment: .topLeading) {
                // Each day is its own cached layer, so only the set of three
                // changes when the wheel crosses a boundary. Panning never
                // re-samples a path.
                HStack(alignment: .top, spacing: 0) {
                    ForEach(firstDay...(firstDay + 2), id: \.self) { index in
                        ArcContent(
                            day: model.solarDay(index),
                            width: dayWidth,
                            height: arcHeight,
                            skyHours: model.sky(forDayIndex: index),
                            daySeed: index
                        )
                        .equatable()
                    }
                }
                .frame(width: dayWidth * 3, alignment: .topLeading)
                .offset(x: pan, y: topInset)

                EventLayer(
                    events: model.timedEvents,
                    originHour: originHour,
                    pointsPerHour: pointsPerHour,
                    width: dayWidth * 3,
                    height: arcHeight,
                    activeID: model.activeEvent?.id,
                    elevation: { model.normalizedElevation(atAbsoluteHour: $0) }
                )
                .offset(x: pan, y: topInset)

                Rectangle()
                    .fill(Theme.hairlineSoft)
                    .frame(width: 1, height: max(0, topInset + arcHeight - dotY))
                    .position(x: centreX, y: (topInset + arcHeight + dotY) / 2)

                TimeDot(
                    elevationDegrees: model.elevationDegrees(atAbsoluteHour: model.focusHour),
                    moon: model.focusMoonPhase,
                    ceilingDegrees: model.focusSolarDay.seasonalCeiling
                )
                .position(x: centreX, y: dotY)
            }
            .frame(width: proxy.size.width, height: topInset + arcHeight + ArcContent.labelGutter, alignment: .topLeading)
            .clipped()
        }
        .frame(height: topInset + arcHeight + ArcContent.labelGutter)
    }
}
