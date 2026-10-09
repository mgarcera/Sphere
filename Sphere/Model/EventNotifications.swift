import Foundation
import Observation
import UserNotifications

/// Local notifications for calendar events. Decided 2026-10-09, recorded in DECISIONS.
///
/// Every timed event gets one, including events that already carry an Apple alarm, so an event
/// with a 10-minute Calendar alert and Sphere's default 10-minute lead produces two notifications
/// at the same minute. That is a known cost of the feature working at all: filtering to events
/// with no `EKAlarm` never double-buzzes and also never fires for anyone who sets alerts, and it
/// leaks anyway — Settings ▸ Calendar ▸ Default Alert Times and Calendar's "Time to Leave" both
/// produce alerts that need not exist as readable `EKAlarm` objects.
///
/// Nothing here fetches anything. The body is the lead time and the all-day trigger is the sun,
/// both computed locally, because a notification's text is frozen when it is scheduled rather than
/// when it fires — which is the whole reason weather is out of v1.
@MainActor
@Observable
final class EventNotifications {
    enum Permission: Equatable { case undetermined, granted, denied }

    /// How far ahead to schedule. Not "everything": the only documented ceiling on pending
    /// requests is 64 per app, it lives on a page Apple marks deprecated, and no current document
    /// states any number. A full calendar reaches whatever the real ceiling is within days, so the
    /// schedule is a rolling window rebuilt on every launch and every calendar change.
    private static let horizon: TimeInterval = 7 * 24 * 60 * 60
    /// Well under 64, so Sphere never finds out what the undocumented behaviour at the limit is.
    private static let maxRequests = 48
    /// Used when `SolarDay.sunrise` is nil, which happens at a latitude where the sun does not
    /// rise that day. A notification at a plausible hour beats no notification.
    private static let sunlessFallbackHour = 7.0

    private static let enabledKey = "notificationsEnabled"
    private static let leadKey = "notificationLeadMinutes"

    private(set) var permission: Permission = .undetermined

    /// Without a delegate, iOS delivers a notification while the app is frontmost and shows
    /// nothing — which is exactly what a developer testing the feature sees, and reads as "it
    /// didn't fire" (Mason, 2026-10-09). Held as a property because
    /// `UNUserNotificationCenter.delegate` is weak.
    private let presenter = ForegroundPresenter()

    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
        }
    }

    /// Minutes before the event. 10 by default, adjustable, because a fixed lead loses anyone who
    /// commutes — they turn the feature off rather than tune it.
    var leadMinutes: Int {
        didSet {
            guard leadMinutes != oldValue else { return }
            UserDefaults.standard.set(leadMinutes, forKey: Self.leadKey)
        }
    }

    static let leadChoices = [0, 5, 10, 15, 30, 60]

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        let stored = UserDefaults.standard.object(forKey: Self.leadKey) as? Int
        leadMinutes = stored ?? 10
        UNUserNotificationCenter.current().delegate = presenter
    }

    /// Shows the banner even when Sphere is frontmost. The HIG argues for handling the foreground
    /// case "discoverable but not distracting" and Sphere's arc does already move on its own, but a
    /// reminder you asked for ten minutes before an event is the one thing that should not be
    /// swallowed because you happened to be looking at the app.
    private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
            [.banner, .sound]
        }
    }

    // MARK: - Permission

    func refreshPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permission = Self.permission(from: settings.authorizationStatus)
    }

    /// Asks for the real prompt, deliberately without `.provisional`.
    ///
    /// Provisional authorization needs no prompt, and that is its trap: pressing Keep does not
    /// promote it to banners, it authorises quiet delivery only — no alert, no sound, no badge, no
    /// lock screen, Notification Center history alone — until the person changes Settings
    /// themselves. A reminder ten minutes before an event that nobody sees is worse than none.
    @discardableResult
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshPermission()
        return granted
    }

    private static func permission(from status: UNAuthorizationStatus) -> Permission {
        switch status {
        case .notDetermined: .undetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .granted
        @unknown default: .denied
        }
    }

    // MARK: - Scheduling

    /// Tears the schedule down and rebuilds it. Cheap enough to do on every launch, every
    /// foreground and every `EKEventStoreChanged`, which is the only signal there is: that
    /// notification is an `NSNotification` on the default center, so it is delivered only while
    /// Sphere is running. An event deleted in Calendar.app while Sphere is terminated still fires,
    /// and no API prevents it.
    func reschedule(using calendar: CalendarService,
                    coordinate: Coordinate,
                    timeZone: TimeZone,
                    now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        guard isEnabled, permission == .granted else {
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier))
            return
        }

        let candidates = calendar.scheduleCandidates(from: now, to: now.addingTimeInterval(Self.horizon))
        var requests = timedRequests(from: candidates, now: now)
        requests += allDayRequests(from: candidates,
                                   coordinate: coordinate,
                                   timeZone: timeZone,
                                   now: now)
        let desired = Array(requests.sorted(by: Self.fires).prefix(Self.maxRequests))

        // A diff rather than a tear-down. Removing everything and immediately re-adding puts a
        // removal and an add in flight at once, and an identifier carries its own fire time (the
        // lead minutes and the sunrise minute are both in it), so anything still wanted is
        // byte-identical to what is already scheduled and can simply be left alone.
        let desiredIDs = Set(desired.map(\.identifier))
        let pendingIDs = Set(pending.map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers: Array(pendingIDs.subtracting(desiredIDs)))
        for request in desired where !pendingIDs.contains(request.identifier) {
            try? await center.add(request)
        }
    }

    /// Soonest first, so the cap keeps the near future rather than an arbitrary slice of it.
    private static func fires(_ a: UNNotificationRequest, _ b: UNNotificationRequest) -> Bool {
        (a.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
            < (b.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
    }

    private func timedRequests(from candidates: [ScheduleCandidate], now: Date) -> [UNNotificationRequest] {
        candidates.filter { !$0.isAllDay }.compactMap { event in
            let fireAt = event.start.addingTimeInterval(-Double(leadMinutes) * 60)
            // An event starting inside the lead window has already passed its notification.
            guard fireAt > now else { return nil }
            // The lead is part of the identity: without it, changing the lead time leaves the old
            // trigger in place because the identifier still matches.
            return Self.request(id: "timed-\(leadMinutes)-\(event.id)",
                                title: Self.name(event.title),
                                body: Self.leadBody(leadMinutes),
                                fireAt: fireAt,
                                now: now)
        }
    }

    /// All-day events notify at sunrise rather than at midnight — Sphere's clock rather than the
    /// calendar's — and several on one day become ONE notification, because the alternative is
    /// three simultaneous buzzes at dawn.
    private func allDayRequests(from candidates: [ScheduleCandidate],
                                coordinate: Coordinate,
                                timeZone: TimeZone,
                                now: Date) -> [UNNotificationRequest] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let byDay = Dictionary(grouping: candidates.filter(\.isAllDay)) {
            calendar.startOfDay(for: $0.start)
        }

        return byDay.compactMap { midnight, events in
            let solar = SolarDay(date: midnight, coordinate: coordinate, timeZone: timeZone)
            let hour = solar.sunrise ?? Self.sunlessFallbackHour
            guard let fireAt = calendar.date(byAdding: .second,
                                             value: Int(hour * 3600),
                                             to: midnight),
                  fireAt > now else { return nil }

            let names = events.map { Self.name($0.title) }
            // Minute-of-day in the identity for the same reason: moving location moves sunrise.
            return Self.request(id: "allday-\(Int(midnight.timeIntervalSince1970))-\(Int(hour * 60))",
                                title: names.count == 1 ? names[0] : "All day",
                                body: names.count == 1 ? "All day." : names.joined(separator: ". ") + ".",
                                fireAt: fireAt,
                                now: now)
        }
    }

    private static func request(id: String,
                                title: String,
                                body: String,
                                fireAt: Date,
                                now: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // Not `.timeSensitive`: it breaks through Focus and Sleep, it needs a capability whose
        // entitlement key Apple does not document, and Apple's own qualifying examples are account
        // security and medication. An event reminder is not either of those.
        content.interruptionLevel = .active

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(fireAt.timeIntervalSince(now), 1),
                                                        repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    /// An untitled event is legal in Calendar and renders as a blank line otherwise.
    private static func name(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Event" : trimmed
    }

    /// The body is the time alone, in the app's register: no commas, one statement, a full stop.
    /// Three bodies were drafted on 2026-10-09 and the two that named the sky were cut, so this
    /// says nothing Apple's own alert does not. Its value is firing for events Apple is silent on.
    static func leadBody(_ minutes: Int) -> String {
        switch minutes {
        case ..<1: "Now."
        case 1: "In 1 minute."
        case 60: "In 1 hour."
        default: "In \(minutes) minutes."
        }
    }
}
