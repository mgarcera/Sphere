# Day Arc — Product Brief (v1, iOS transfer)

## What it is

A day planner that replaces the list with a **single arc representing the day**, shaped by the actual sun's elevation for the user's location and date. Tasks, sunrise/midday/sunset, and a planetary-hours system all live on that one line. A skeuomorphic click wheel (iPod-style) is the primary way to move through the day.

Two modes:
- **Universal** — works for anyone, no personal data. Sun position, moon phase/sign, day ruler, planetary hours.
- **Personal** — adds a natal chart (from birth date/time/place) and shows today's transits to that chart, personalizing the planetary-hour call-to-action when relevant.

This app has one screen. There is no navigation stack in v1.

---

## Core concept: the arc

- The arc's **shape is not decorative** — it's the sun's elevation curve for today, at the user's location, computed from real sunrise/sunset times (currently hardcoded to Chicago; see Open Items).
- Full day = midnight to midnight. The curve rises from sunrise, peaks at solar noon, falls to sunset, flat (baseline) overnight. Peak height scales with day length, so the hill is visibly taller in summer, shallower in winter.
- The **arc's stroke is colored** in segments — each planetary hour (see below) tints that stretch of the line with its ruling planet's color. No separate legend/strip; the line itself carries the information.
- The view is **zoomed to a 3-hour window**, always centered on the current time dot. The dot never moves on screen — the arc's content pans underneath it as the wheel turns.

## The click wheel

- A drag-or-scroll circular control, styled like a classic iPod click wheel (chrome/white, no color).
- One full physical rotation = 4 hours of in-app time. Takes a few turns to cross a whole day, intentionally — matches the tactile feel of the original hardware.
- **MENU** (top) — jumps the time dot back to the real current time.
- **‹ ›** (left/right) — jump directly to the next/previous task's hour (not a generic time nudge).
- **Center button** — opens/closes the "add something" inline text field, which creates a task at whatever hour the wheel is currently on.

## Tasks

- A task is just `{ id, hour, label }` — no duration, no end time, no category.
- Tasks appear on the arc as dots, in a dedicated blue (distinct from the planetary-hour palette so they read as "yours").
- **A task's name only appears in the title when the time dot is within 15 minutes of it.** There is no "next upcoming task" default — the title is proximity-driven, not schedule-driven. Outside that 15-minute window, the title shows the current planetary hour's call-to-action instead (see below).

## Planetary hours (Universal mode)

This is a real historical system (Hellenistic/Chaldean), not invented for this app — worth preserving as-is rather than "simplifying":

- Sunrise-to-sunset and sunset-to-sunrise are each split into **12 unequal ("temporal") hours** — their length depends on day length, not the clock.
- The 7 classical planets (Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn — pre-dates Uranus/Neptune/Pluto by design) cycle through those 24 hours in a fixed order (Saturn, Jupiter, Mars, Sun, Venus, Mercury, Moon, repeating), starting from whichever planet rules the weekday.
- Each planet has a short **call-to-action** phrase used as the default title text: e.g. *"Mars hour. Take action."* / *"Venus hour. Connect."* — see `PLANET_CTA` in code for the full set.
- The corner badge also shows: the day's ruling planet ("Sunday · Sun's day"), current moon phase (custom two-circle-overlap icon, not a system glyph), the moon's zodiac sign, and a Mercury retrograde flag when active.

## Personal mode (natal chart)

- One-time form: birth date, time, UTC offset (manually entered, see Open Items), latitude/longitude, place name.
- Computes: natal placements for all 7 classical planets (sign, degree, house), Ascendant, Midheaven, and 12 house cusps using the **Equal House system** (not Placidus — see Open Items).
- Computes **today's transits to the natal chart**: for each of today's 7 transiting planet positions, checks the 5 major aspects (conjunction, opposition, trine, square, sextile) against each of the 7 natal placements, within standard orbs (4–6°).
- **Personalization hook**: if the currently active planetary hour's ruling planet also has a live transit-to-natal aspect today, that aspect is appended under the caption (e.g. *"Venus trine your Sun"*), in the planet's color.
- A collapsible chart summary (placements + today's transit list) lives below the wheel.

---

## Visual design system

**Palette** (carry these into an Asset Catalog as named colors):

| Role | Hex |
|---|---|
| Background | `#FFFFFF` |
| Primary text ("ink") | `#2B2620` |
| Muted text | `#8A8A8A`, `#A3A3A3`, `#B5B5B5` |
| Hairlines/dividers | `#ECECEC`, `#E5E5E5` |
| Task (event) — active | `#3B6FA0` |
| Task (event) — inactive | `#A9C6E3` |
| Sun | `#C46A3E` |
| Moon | `#7C8A9E` |
| Mercury | `#5B8C85` |
| Venus | `#D8B04A` |
| Mars | `#B3453A` |
| Jupiter | `#7E9B76` |
| Saturn | `#8C7AA6` |

**Typography** — the prototype uses a serif (Iowan Old Style/Palatino/Georgia stack) for the title/display text and a sans (Inter/system) for everything else. On iOS, map this to:
- Display/title → **New York** (Apple's system serif) at a Title-2/Title-3-ish size (~22pt, matches current)
- UI/body/labels → **SF Pro** (system default), following HIG's type scale (Footnote 13pt for time/muted labels, Subhead/Callout ~15–17pt for planet names)

No emoji, no astrology glyphs (☉☽♀ etc. were explicitly removed in favor of plain colored dots) — keep it that way. No decorative icons beyond the custom moon-phase shape.

---

## Technical translation notes (React → SwiftUI)

| React prototype | SwiftUI equivalent |
|---|---|
| Inline `<svg>` with hand-built `path` strings, sampled point-by-point from the sine-based elevation function | A `Shape` (or `Canvas`) that samples the same function and builds a `Path` via `addLine(to:)` — port `yForHour()` and the sampling loop directly |
| `ResizeObserver` measuring the container to avoid viewBox/CSS scale mismatch | `GeometryReader` — read `proxy.size.width` directly, no scale-matching workaround needed since SwiftUI doesn't have the CSS-viewBox scaling problem in the first place |
| Horizontal pan via `transform: translate()` on a `<g>` | `.offset(x:)` on the drawn content, or shift the sampling window's x-origin before building the `Path` |
| Click wheel: `pointerdown/pointermove` + `atan2` angle math, `onWheel` for scroll | `DragGesture` computing angle via `atan2` relative to the wheel's center; **note**: iOS has no native scroll-wheel input — decide whether to drop that interaction or substitute a two-finger scroll gesture |
| `useState`/`useMemo` for `now`, `tasks`, `mode`, `birthData` | `@State` / `@Observable` model object; consider `SwiftData` or `UserDefaults` for persistence (**the prototype has none — tasks and birth data vanish on reload**) |
| Custom `MoonPhaseIcon` (two overlapping circles clipped to a disc) | Same technique via `Canvas` or two `Circle()` shapes with a `.clipShape` |
| Orbital-mechanics math (Kepler solver, Schlyter low-precision elements) in plain JS functions | Direct line-for-line port to Swift — it's pure math, no DOM/browser dependency. Longer-term, consider swapping in a real astronomy package (e.g. SwiftAA) for better precision, especially for the Ascendant/house calculations |

### Data models (starting point)

```swift
struct DayTask: Identifiable {
    let id: UUID
    var hour: Double   // 0..24, fractional
    var label: String
}

struct BirthData {
    var date: Date
    var utcOffsetHours: Double
    var latitude: Double
    var longitude: Double
    var place: String
}

struct NatalPlacement {
    var longitude: Double
    var sign: String
    var degree: Double
    var house: Int
}

struct NatalChart {
    var planets: [String: NatalPlacement]   // keyed by "sun","moon",...
    var ascendant: NatalPlacement
    var midheaven: NatalPlacement
    var houseCusps: [Double]                // 12 values
}

struct TransitAspect {
    var transitingBody: String
    var natalBody: String
    var aspect: String   // "conjunction","trine",...
    var orb: Double
}
```

---

## Open items — verify or decide before shipping

**Astrology accuracy (flagged earlier in the design process, not yet resolved):**
- The Ascendant/Midheaven formula is implemented from a standard published equation, not verified against a reference ephemeris. Test against a known chart (the user's own) before trusting it.
- Houses use **Equal House**, not Placidus — the more common default elsewhere. Cusps will differ from other chart apps; decide if that needs to change or just needs a label.
- Birth-time-to-UT conversion requires the user to manually enter a UTC offset — there's no timezone/DST lookup. Wrong offset silently produces a wrong chart.
- All planetary positions (natal and transit) use a low-precision orbital-element method (~1 arcminute-ish accuracy), fine for this app's purposes but not ephemeris-grade.

**Product scope decisions still open:**
- Location is hardcoded to Chicago (`lat: 41.8781, lon: -87.6298`) for the Universal-mode sun/moon calculations — needs a real location source (Core Location, or a manual city picker) for v1.
- No persistence layer yet — tasks, mode, and birth data are all in-memory only.
- Only "today" is supported — no navigating to other days.
- No notifications/reminders tied to tasks or planetary-hour transitions.
- The click wheel's scroll-to-scrub interaction has no direct iOS equivalent (see table above) — needs a decision.

---

## Suggested v1 build order

1. Static arc rendering (sun curve, sunrise/midday/sunset markers) for a hardcoded location — validates the `Shape`/`Canvas` approach before anything interactive.
2. Click wheel + pan/zoom behavior, wired to a `now` state.
3. Task model + add/display + 15-minute proximity title logic.
4. Planetary hours (Chaldean sequence, colored arc segments, CTA copy) — pure calendar math, no location dependency beyond sunrise/sunset already computed in step 1.
5. Moon phase/sign, day ruler, Mercury retrograde badge.
6. Personal mode: birth-data form → natal chart calc → transit-to-natal aspect list → personalization hook in the caption.
7. Persistence (SwiftData/UserDefaults) for tasks and birth data.
