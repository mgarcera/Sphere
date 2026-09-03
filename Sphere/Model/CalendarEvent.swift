import SwiftUI
import UIKit

/// One occurrence of a calendar event, flattened into the arc's coordinate
/// space. Hours are measured from the model's anchor midnight and are
/// unbounded, so an event tomorrow afternoon sits somewhere past 24.
struct CalendarEvent: Identifiable, Equatable {
    /// A recurring event shares one `eventIdentifier` across every occurrence,
    /// so the start has to be part of the identity or a weekly meeting
    /// collapses into a single dot.
    let id: String
    let eventIdentifier: String
    let title: String
    let startHour: Double
    let endHour: Double
    let isAllDay: Bool
    let color: Color

    var durationHours: Double { endHour - startHour }

    func contains(_ hour: Double) -> Bool {
        hour >= startHour && hour < endHour
    }
}

extension CalendarEvent {
    /// The capsule colour as components, for the snapshot the widgets read.
    var snapshotColor: SnapshotColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return SnapshotColor(red: Double(r), green: Double(g), blue: Double(b))
    }
}
