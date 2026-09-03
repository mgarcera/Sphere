import SwiftUI

/// Which mark each wheel action and each tap is drawn as.
///
/// The marks themselves live in `Shared/ActionMark.swift`, since the widgets
/// draw them too; what stays here is the mapping, which is about the wheel and
/// means nothing outside the app.
extension WheelAction {
    var mark: Mark {
        switch self {
        case .none: .none
        case .now: .now
        case .calendar: .calendar
        case .previousDay: .previousDay
        case .nextDay: .nextDay
        case .newAllDay: .newAllDay
        case .appearance: .appearance
        case .search: .search
        case .openCalendarApp: .openCalendarApp
        case .muteHaptics: .muteHaptics
        }
    }
}

extension WheelPosition {
    /// What tapping this position looks like. The bottom's follows its setting.
    var tapMark: Mark {
        switch self {
        case .previous: .previousEvent
        case .next: .nextEvent
        case .menu: .menu
        case .centre: .openEvent
        case .bottom: WheelMapping.bottomPrimary.mark
        }
    }
}
