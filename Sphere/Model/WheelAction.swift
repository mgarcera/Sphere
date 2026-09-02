import Foundation

/// Where a wheel position can send you.
///
/// Only the actions with nowhere else to live. Creating an event and opening
/// the menu already own a position each, so putting them in the pool would hand
/// out duplicates rather than access.
enum WheelAction: String, CaseIterable, Identifiable {
    case none
    case now
    case calendar
    case previousDay
    case nextDay
    case newAllDay
    case appearance
    case search
    case openCalendarApp
    case muteHaptics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .now: "Now"
        case .calendar: "Calendar"
        case .previousDay: "Previous day"
        case .nextDay: "Next day"
        case .newAllDay: "New all-day event"
        case .appearance: "Light / dark"
        case .search: "Search"
        case .openCalendarApp: "Open in Calendar"
        case .muteHaptics: "Mute haptics"
        }
    }
}

enum WheelGesture { case tap, hold }

/// The five places a finger lands on the wheel.
enum WheelPosition: String, CaseIterable, Identifiable {
    case previous
    case menu
    case next
    case bottom
    case centre

    var id: String { rawValue }

    /// What is printed at that spot on the wheel.
    var label: String {
        switch self {
        case .previous: "‹"
        case .menu: "MENU"
        case .next: "›"
        // The one position whose word depends on what it is set to.
        case .bottom: WheelMapping.bottomPrimary == .calendar ? "DATE" : "NOW"
        case .centre: "●"
        }
    }

    /// What tapping it does. Fixed everywhere but the bottom: a control whose
    /// printed word can come to mean something else stops being readable, and
    /// the bottom's word changes with it.
    var tapTitle: String {
        switch self {
        case .previous: "Previous event"
        case .menu: "Menu"
        case .next: "Next event"
        case .bottom: WheelMapping.bottomPrimary.title
        case .centre: "Open event"
        }
    }

    /// Holds ship where the pairing writes itself and empty where it does not.
    /// A chevron already steps by event, so stepping by day is the same gesture
    /// at a longer reach. MENU and the centre have no obvious second meaning,
    /// and inventing one to fill the slot is worse than a slot that admits to
    /// being empty.
    var defaultHold: WheelAction {
        switch self {
        case .previous: .previousDay
        case .next: .nextDay
        case .bottom: .calendar
        // The same rule the chevrons follow: tap is the fine-grained thing,
        // hold is its day-scale twin. It was also the only way to make an
        // all-day event at all — the header row appears once one exists, so
        // there was no affordance for the first.
        case .centre: .newAllDay
        // The one position the day-scale rule does not reach: its tap is
        // app-scale, so its hold is too. Empty was a placeholder held while
        // there was nothing worth putting there.
        case .menu: .appearance
        }
    }

    /// What this position will accept on its hold.
    ///
    /// Not one pool but one per position, because the wheel is not a flat list
    /// of slots. The time positions move the day and take actions that move the
    /// day; MENU is app-scale and takes app-scale actions. A wheel where mute
    /// haptics could sit on a chevron would have five slots and no shape.
    var assignableActions: [WheelAction] {
        switch self {
        case .previous, .next:
            [.none, .now, .calendar, .previousDay, .nextDay, .newAllDay]
        case .menu:
            [.none, .appearance, .search, .openCalendarApp, .muteHaptics]
        // Fixed: the centre makes events and nothing else, and the bottom's
        // hold is whichever of the pair its tap is not.
        case .centre, .bottom:
            []
        }
    }

    var holdIsAssignable: Bool { !assignableActions.isEmpty }

    var storageKey: String { "wheelHold.\(rawValue)" }
}

/// What each position does, read by the wheel and written by settings.
@MainActor
enum WheelMapping {
    static let bottomKey = "wheelBottomPrimary"

    /// Tapping the bottom. The other of the pair falls to its hold, so both are
    /// always one gesture away and neither is ever orphaned.
    static var bottomPrimary: WheelAction {
        guard let raw = UserDefaults.standard.string(forKey: bottomKey),
              let action = WheelAction(rawValue: raw)
        else { return .now }
        return action
    }

    static func tap(for position: WheelPosition) -> WheelAction {
        position == .bottom ? bottomPrimary : .none
    }

    static func hold(for position: WheelPosition) -> WheelAction {
        switch position {
        case .bottom: return bottomPrimary == .now ? .calendar : .now
        case .centre: return .newAllDay
        default: break
        }
        guard let raw = UserDefaults.standard.string(forKey: position.storageKey),
              let action = WheelAction(rawValue: raw),
              // A pool that narrows leaves old assignments behind. Anything no
              // longer offered here falls back rather than staying set to
              // something the settings wheel can no longer show.
              position.assignableActions.contains(action)
        else { return position.defaultHold }
        return action
    }

    static func setHold(_ action: WheelAction, for position: WheelPosition) {
        UserDefaults.standard.set(action.rawValue, forKey: position.storageKey)
    }
}
