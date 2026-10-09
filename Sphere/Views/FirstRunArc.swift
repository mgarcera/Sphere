import SwiftUI

/// The real arc, on a sample day, for the two first-run screens.
///
/// `ArcWindow` rather than `MiniArc` because that is what the app actually shows: three hours
/// wide, the dot nailed to the centre, the arc sliding underneath. A whole-day hill is the menu's
/// summary view, and the website's own note says the narrow layout "windows and pans, exactly as
/// `ArcWindow` does" (2026-10-04).
///
/// Sample data, because neither screen has what it needs yet — no calendar on the first, no
/// location on the second. That is the same reason the App Store assets use a fictional day.
struct FirstRunArc: View {
    /// Whether the sky is the slightly cloudy one. Off for the calendar screen, on for the sky one.
    var weather = false

    @State private var model = DayModel(now: Self.sampleNoon, coordinate: .chicago)
    @State private var started = false
    @State private var clouding = false

    /// Chicago, **Sunday 2025-08-03 at 07:00 CDT** (12:00 UTC). Not noon, and not the Monday in
    /// 2026 the store captures are set on, whatever the name says — it is an early-morning start
    /// so the 1.5-hour pan below has somewhere to climb to. The date only feeds sunrise and sunset;
    /// no weekday or date is drawn on this screen, which is why it went three weeks unnoticed.
    /// Changing it changes where the arc sits at launch, so it is a look decision, not a fix.
    private static let sampleNoon = Date(timeIntervalSince1970: 1_754_222_400)

    var body: some View {
        // No `.frame(height:)` here, and that is the fix for a bug that shipped unseen
        // (2026-10-09). `ArcWindow` sizes itself to `ArcGeometry.totalHeight(arcHeight)` — the
        // arc plus the 100pt sky gutter that keeps tall clouds unclipped, about 290 for a 190
        // arc. This used to pin it to 190, a hundred points under its minimum. On every iPhone
        // Sphere had ever run on the enclosing column had slack and the squeeze resolved
        // quietly; on an iPhone Duo's 678-tall outer display it did not, and the ENTIRE
        // onboarding screen rendered nothing — no title, no button, just the sky behind it.
        // A child crushed below its minimum can take its whole parent down with it.
        ArcWindow(model: model, arcHeight: 190)
            .allowsHitTesting(false)
            .task { await run() }
            // The view is not rebuilt between screens — that is the point — so the weather build
            // has to start from the parameter changing rather than from a fresh `task`.
            .task(id: weather) { if weather { await buildWeather() } }
    }

    private func run() async {
        guard !started else { return }
        started = true

        model.applySky(sky(cloudy: false), forDayIndex: model.dayIndex)

        // Screen one moves fast and settles fast: an hour and a half in five seconds, easing out,
        // so it has clearly moved and is clearly done by the time anyone decides (Mason, 2026-10-04).
        withAnimation(.easeOut(duration: 5)) { model.focusHour += 1.5 }
    }

    /// Screen two: the arc carries on from where screen one settled, moves the same distance at
    /// the same speed, and settles. The sky is already slightly cloudy when it arrives.
    ///
    /// No fade. The cloud is set once, at full value, before the pan starts — a sky that builds
    /// up while someone reads is a weather animation, and this is just a clear day becoming a
    /// slightly cloudy one (Mason, 2026-10-04).
    private func buildWeather() async {
        guard !clouding else { return }
        clouding = true

        model.applySky(sky(cloudy: true), forDayIndex: model.dayIndex)

        // Opposite screen one ON THE ARC, which is a mirror about solar noon rather than a fixed
        // offset: the same elevation, on the way down instead of the way up. Twelve hours later
        // would be the clock's opposite and lands past sunset on this day, giving a night sky with
        // stars rather than the slightly cloudy afternoon the line is about (Mason, 2026-10-04).
        //
        // Computed from the day rather than written down, so it stays right if the sample date
        // ever moves.
        let noon = model.solarDay(model.dayIndex).solarNoon
        let mirrored = 2 * noon - model.focusHour
        model.focusHour = mirrored - 1.5

        // Then the same move as screen one: fast, and settled.
        withAnimation(.easeOut(duration: 5)) { model.focusHour += 1.5 }
    }

    /// One day of hours, clear or slightly cloudy.
    ///
    /// **Short runs, not a blanket.** Cloud is counted in drawn width rather than in hours, so a
    /// cover applied to every hour becomes one long wedge across a three-hour window instead of
    /// clouds. One cloudy hour every three gives separate, regular puffs at this zoom — the
    /// website hit the same thing and its note says so (2026-10-04).
    ///
    /// Birds come free with a clear low deck, which is why screen one has them and screen two
    /// keeps most of them.
    private func sky(cloudy: Bool) -> [SkyHour] {
        let day = model.solarDay(model.dayIndex)
        return (0..<24).map { hour in
            let puff = cloudy && hour % 3 == 1
            return SkyHour(
                hour: hour,
                condition: puff ? .partlyCloudy : .clear,
                isDaylight: day.elevation(atHour: Double(hour) + 0.5) >= 0,
                cloudLow: puff ? 0.30 : 0,
                cloudMid: puff ? 0.52 : 0,
                cloudHigh: 0,
                precipitation: 0,
                wind: 0,
                cape: 0
            )
        }
    }
}
