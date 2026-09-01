import SwiftUI

/// Events as capsules riding the curve from start to end, so visual extent is
/// time extent and nothing can misrepresent when something happens. The stroke
/// has round caps, so a very short event still renders as a sphere — that is
/// where the sphere comes from now, rather than a separate dot.
struct EventLayer: View {
    let events: [CalendarEvent]
    /// Absolute hour sitting at this layer's x origin.
    let originHour: Double
    let pointsPerHour: CGFloat
    let width: CGFloat
    let height: CGFloat
    let activeID: CalendarEvent.ID?
    let elevation: (Double) -> Double

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(events) { event in
                let isActive = event.id == activeID

                capsulePath(for: event)
                    .stroke(
                        event.color.opacity(isActive ? 1 : 0.5),
                        style: StrokeStyle(lineWidth: isActive ? 5 : 4, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .frame(width: width, height: height + ArcContent.labelGutter, alignment: .topLeading)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: activeID)
    }

    private func point(at hour: Double) -> CGPoint {
        CGPoint(
            x: (hour - originHour) * pointsPerHour,
            y: height - height * elevation(hour)
        )
    }

    private func capsulePath(for event: CalendarEvent) -> Path {
        var path = Path()
        let span = max(event.durationHours, 0)
        let steps = max(1, min(240, Int(span * 12)))

        for step in 0...steps {
            let hour = event.startHour + span * Double(step) / Double(steps)
            let position = point(at: hour)
            if step == 0 { path.move(to: position) } else { path.addLine(to: position) }
        }
        return path
    }
}
