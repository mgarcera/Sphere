import Foundation

/// The seven classical planets, in Chaldean order (slowest to fastest).
/// Uranus, Neptune and Pluto are excluded by design, not by omission.
enum Planet: String, CaseIterable, Identifiable {
    case saturn, jupiter, mars, sun, venus, mercury, moon

    var id: String { rawValue }

    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    /// Mason's copy, kept deliberately. Planetary hours are out of v1 (see
    /// DECISIONS.md, "Planetary hours have no surface"), so nothing calls this
    /// yet; re-deriving the seven lines later is the worse cost.
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
