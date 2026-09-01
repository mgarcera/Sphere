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

    /// Call-to-action shown as the default title text during this planet's hour.
    /// The brief supplies Mars and Venus; the remaining five come from the
    /// prototype's `PLANET_CTA` table, which has not been transferred yet.
    var callToAction: String? {
        switch self {
        case .mars:  "Mars hour. Take action."
        case .venus: "Venus hour. Connect."
        default:     nil
        }
    }
}
