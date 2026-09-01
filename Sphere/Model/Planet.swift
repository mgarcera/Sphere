import SwiftUI

/// The seven classical planets, in Chaldean order (slowest to fastest).
/// Uranus, Neptune and Pluto are excluded by design, not by omission.
enum Planet: String, CaseIterable, Identifiable {
    case saturn, jupiter, mars, sun, venus, mercury, moon

    var id: String { rawValue }

    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    var color: Color {
        Color(displayName)
    }

    /// Title text shown for the whole of this planet's hour — the screen's
    /// default state, replaced only when the time dot comes within 15 minutes
    /// of a task.
    var callToAction: String {
        switch self {
        case .sun:     "Sun hour. Be Seen."
        case .moon:    "Moon hour. Rest and reflect."
        case .mercury: "Mercury hour. Reach out."
        case .venus:   "Venus hour. Connect."
        case .mars:    "Mars hour. Take action."
        case .jupiter: "Jupiter hour. Think big."
        case .saturn:  "Saturn hour. Get it done."
        }
    }
}
