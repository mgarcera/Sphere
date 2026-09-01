# Sphere — decisions that amend the brief

`PRODUCT_BRIEF.md` is the original handoff. Where this file disagrees with it,
this file wins. Dates are when the decision was made.

## 2026-09-01 — Calendar replaces the task model

**Everything on the arc is a real `EKEvent`.** `DayTask` is removed. There is no
local task type, so the app needs full calendar access to show anything of the
user's. Without it the arc, the sun markers and the planetary hours still work,
which is the brief's Universal mode.

**Duration is length along the arc.** An event is a capsule running from its
start to its end. A short event collapses to a dot, so a sphere is the
degenerate case of the capsule rather than a second kind of mark. Sizing a
sphere by duration was rejected: position on the arc is already true-to-scale
time, and a second time encoding on the same axis contradicts the first.

**The centre button opens `EKEventEditViewController` immediately**, empty
title, start at the wheel's hour. The inline "add something" field is removed.
Tapping an existing event opens `EKEventViewController`, which carries edit and
delete without us building either.

**Other days are reachable, and the wheel is how you reach them.** The 0...24
clamp on `focusHour` is gone; turning past midnight carries into the next or
previous day. No second time-navigation control competes with the wheel.

**The arc is one continuous curve across midnight.** The sun's elevation really
is continuous at the day boundary, so the curve joins with no seam. A hairline
at midnight and the date in the header carry the day change.

**Events take their own `EKCalendar` colour.** This overrides the brief's rule
that blue is reserved for the user's own marks. The tradeoff was named and
accepted: telling work from personal at a glance is worth the wider palette.

**The seven planetary colours are deleted from the asset catalog.** They were
for the brief's per-planetary-hour arc tinting, which is dropped (see below).
Nothing references them. The hex values live in `PRODUCT_BRIEF.md` if a use
returns.

**Full calendar access is requested behind a priming screen**, shown before the
system prompt. iOS only asks once, so a cold denial is close to permanent.

## 2026-09-01 — Planetary hours have no surface

The brief tints each planetary hour's stretch of the arc stroke with its ruling
planet's colour, with no legend, on the grounds that "the line itself carries
the information". Dropped. The view is a three-hour window, so at most one or
two planetary hours are ever visible and there is nothing to compare a tint
against. The stroke stays a single weight in ink.

The replacement was going to be a tarot-style line-art card per planet in the
header. Three styles were drawn and the whole idea was then **removed**.

So the planetary-hours system currently has nowhere to appear. `Planet` still
holds the seven call-to-action lines and is still used by the natal chart types,
but nothing renders an hour's ruling planet or its copy. That is a gap, not a
finished decision.

## 2026-09-01 — Dark mode

Every colour is an asset-catalog pair rather than a single value, and the app no
longer pins itself to light. The wheel's chrome was hardcoded greys; it now has
its own named colours and becomes the black iPod in dark. The twilight wash
carries a second palette, since pastels on a dark ground blow out.

## 2026-09-01 — Weather, location, and the sky band

**Weather sits above the arc, not on it.** Icons live in the empty region above
the curve, each offset along the curve's normal and rotated to its tangent, so
the band runs parallel to the arc and the space reads as sky. One icon per
hour. Line art only, no fill and no colour, at the same weight as everything
else.

**The arc's peak is capped at 65% of its box** so that sky exists at every
season, including midsummer noon when the sun is at its highest. The cost is
that the summer-to-winter height difference now plays out over two thirds of
the box rather than all of it.

**Weather goes behind a `WeatherProvider` protocol, with Open-Meteo first.** It
needs no App ID, no key and no attribution mark, and it reaches 92 days back,
which matters now the wheel reaches any date. WeatherKit becomes a second
conformer the day Sphere needs a provider licensed for commercial use. That
call is deferred with the monetization question.

**Variety comes from data, not from randomness.** The band reads
`cloud_cover_low`, `cloud_cover_mid`, `cloud_cover_high`, `precipitation` and
`wind_speed_10m` alongside the condition code, all in the same call. Coverage
sets a deck's width and lobe count, wind shears it, rainfall sets the number and
length of the fall strokes, and altitude maps to distance out along the arc's
normal, so cirrus draws above cumulus. Twelve consecutive "cloudy" hours in a
real Chicago forecast produce eleven distinct profiles. Where a shape still
needs to look placed rather than stamped it is perturbed by a hash of the day
and hour, never by `random`, so nothing shimmers while the wheel turns.

**The band is one continuous silhouette per deck**, not a mark per hour.
Coverage drives how far the outline bulges and where it breaks, so a clearing
reads as a gap in a drawn sky rather than an absent glyph. The per-hour
`layered` alternative was built, compared on device, and removed along with its
switch.

**Outside the forecast window the band shows nothing.** An empty sky always
means "not known", never "clear". A failed fetch reads the same way.

**Core Location is in, folded into the existing priming screen.** It was always
required: the arc is the sun's elevation curve for a place, and hardcoded
Chicago was a v1 blocker in the brief regardless of weather. Chicago stands in
until a fix arrives and permanently if permission is refused.

## Still open

- **All-day events.** They have no hour and cannot sit on the arc. Going in a
  small modal opened from a navbar button. The navbar does not exist yet and has
  not been designed. The brief says "one screen, no navigation stack in v1",
  so this is a change to that too.
- **Overlapping events** need a tiebreak for the header title. Shortest-wins is
  live and Mason is testing it before confirming.
- **Monetization**, which decides whether Open-Meteo's non-commercial free tier
  is enough or WeatherKit is needed. Deferred to a 6pm block, 2026-09-01.
- **The tilt of the sky band is gentle**, about 8° at most, because a day is
  eight screens wide and the arc is 190pt tall. Exaggerating it is a one-line
  multiplier if the spatial effect needs more.
- **Where the planetary hours live**, now that both the arc tinting and the
  tarot cards are gone.

## Carried over from the brief, unchanged

- Location is still hardcoded to Chicago. Core Location or a city picker is
  still open.
- Ascendant/Midheaven and the Equal House system are still unverified against a
  reference ephemeris.
- Personal mode, the natal chart and transits are untouched by any of the above.
