import StoreKit
import SwiftUI

/// Asking for a rating, at the one kind of moment worth spending the ask on.
///
/// iOS shows at most three of these per person per year and silently drops the rest, so an ask
/// spent on a launch is an ask that cannot be spent later on a finished page. Two rules follow,
/// and they are the whole of this file: ask only after something WORKED, and count those moments
/// rather than launches.
///
/// Added 2026-10-28 to Perzine, Sphere and Weeklite in the same pass, because between them they
/// had three or four ratings. Rating count feeds both App Store search ranking and the product
/// page's conversion rate, so it compounds in a way almost nothing else free does.
///
/// The three copies are deliberate and will drift: each app records a different KIND of moment,
/// which is the only part worth tuning per app. Perzine counts stickers placed, because it has a
/// repeated act of making. The other two count distinct days returned to, because a glanceable
/// app has no act of making and coming back is the honest signal.
enum ReviewMoment {
    /// Internal rather than private: `reviewAsk` watches this key through `@AppStorage`, which is
    /// what turns a `record()` call anywhere in the app into an ask at the root.
    static let countKey = "reviewMoment.count"
    private static let askedVersionKey = "reviewMoment.askedForVersion"
    private static let lastDayKey = "reviewMoment.lastDay"

    /// Something worked. Safe to call anywhere, a gesture handler included: one integer write.
    static func record() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
    }

    /// The same, but at most once per calendar day. For an app with no repeated act of creation,
    /// where the honest signal of someone liking it is that they came back on another day.
    static func recordOncePerDay(_ now: Date = .now) {
        let defaults = UserDefaults.standard
        let day = Calendar.current.startOfDay(for: now).timeIntervalSince1970
        guard defaults.double(forKey: lastDayKey) != day else { return }
        defaults.set(day, forKey: lastDayKey)
        record()
    }

    static func shouldAsk(threshold: Int) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: countKey) >= threshold else { return false }
        // Once per VERSION rather than once ever. A release is a fair moment to ask again, and
        // the system's own three-a-year ceiling is what actually protects the reader from this.
        return defaults.string(forKey: askedVersionKey) != version
    }

    static func markAsked() {
        UserDefaults.standard.set(version, forKey: askedVersionKey)
    }

    private static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}

extension View {
    /// Watches the count `ReviewMoment.record()` keeps, and asks once it is earned.
    ///
    /// Goes on a view that lives as long as the session does, so the ask is not tied to whichever
    /// screen happened to record the last moment: a sheet that records and then dismisses would
    /// otherwise take the pending ask down with it.
    ///
    /// The gate is `>=` rather than `==` on purpose. If a count change is ever missed, the next
    /// recorded moment still opens the gate, so a dropped notification costs a delay and not the
    /// ask itself.
    func reviewAsk(threshold: Int, after delay: Duration = .seconds(1.5)) -> some View {
        modifier(ReviewAsk(threshold: threshold, delay: delay))
    }
}

private struct ReviewAsk: ViewModifier {
    let threshold: Int
    let delay: Duration
    @AppStorage(ReviewMoment.countKey) private var moments = 0
    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        content.onChange(of: moments) { _, _ in
            guard ReviewMoment.shouldAsk(threshold: threshold) else { return }
            // Marked before the wait rather than after: two moments landing in the same second
            // would otherwise both pass the gate and spend two of the three asks on one person.
            ReviewMoment.markAsked()
            Task { @MainActor in
                // Let the thing that just worked finish drawing. A prompt arriving on top of an
                // animation reads as an interruption, which is what earns one star.
                try? await Task.sleep(for: delay)
                requestReview()
            }
        }
    }
}
