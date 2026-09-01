import SwiftUI

/// A three-hour slice of the day. The time dot is nailed to the centre of the
/// screen and never moves; `ArcContent` slides underneath it.
struct ArcWindow: View {
    let day: SolarDay
    let focusHour: Double
    var arcHeight: CGFloat = 190

    var body: some View {
        GeometryReader { proxy in
            let pointsPerHour = proxy.size.width / DayModel.windowHours
            let fullWidth = 24 * pointsPerHour
            let centreX = proxy.size.width / 2
            let dotY = arcHeight - arcHeight * day.normalizedElevation(atHour: focusHour)

            ZStack(alignment: .topLeading) {
                ArcContent(day: day, width: fullWidth, height: arcHeight)
                    .equatable()
                    .offset(x: centreX - focusHour * pointsPerHour)

                // The dot and its drop line are the only things that move with
                // focusHour, and both are cheap.
                Rectangle()
                    .fill(Theme.hairlineSoft)
                    .frame(width: 1, height: max(0, arcHeight - dotY))
                    .position(x: centreX, y: (arcHeight + dotY) / 2)

                Circle()
                    .fill(Theme.taskActive)
                    .frame(width: 9, height: 9)
                    .position(x: centreX, y: dotY)
            }
            .frame(width: proxy.size.width, height: arcHeight + ArcContent.labelGutter, alignment: .topLeading)
            .clipped()
        }
        .frame(height: arcHeight + ArcContent.labelGutter)
    }
}
