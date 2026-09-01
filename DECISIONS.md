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

**The sky is a co-equal element, not a backdrop.** The name is the
architecture: the atmo*sphere* above the line and the work and social *spheres*
on it, sharing one arc. They stay apart by register, ink above versus calendar
colour on the line, rather than by one of them being quiet. Band ink went to
0.8 and inactive capsules to 0.72 to meet it.

**The notch between lobes is shallow.** Deep valleys made the decks read as a
row of humps. The plinth carries 0.78 of a deck's amplitude and the peaks came
down to match, so the valley is 46% of the crest rather than 27%.

**Cloud lobes are puffs, not peaks.** The first attempt at varied lobes read
as a mountain range. Five causes, all fixed together: the lobe profile is a
semicircle rather than a sine, so the sides stand up and the top is round; each
lobe is emitted as smooth quadratic curves through its samples rather than
straight segments; the plinth carries over half the deck's amplitude, so the
deck is a mass with bumps rather than peaks rising from a plain; the lean is
shallow; and the second octave is quiet. Lobe width still varies more than
height, which is what fixed the original uniformity. An overlapping-circles
construction was built as an alternative, compared on device, and removed.

**Clouds are closed bodies, not curves.** The first draft read as wind because
each deck was a stroked open polyline with sine bulges. Three fixes: every deck
is a closed shape with a base and a scalloped top, the scallops are convex
lobes meeting at cusps rather than sine waves, and each deck is filled with the
background before stroking so a nearer deck cuts a hole in the one behind it.
Line art can occlude, and that is what gives the band depth.

**Storms are detected from CAPE, not from the weather code.** Open-Meteo's
thunderstorm code is conservative: in a year of Chicago data it flagged 8 hours
on 5 days, while showers coded 80 to 82 carried a median CAPE of 1260 and are
physically the same cumulonimbus. Frontal rain sits near 30, so instability
separates convective from stratiform cleanly. A cumulonimbus draws at CAPE
>= 1000 with precipitation, lightning at >= 2000, since coded thunderstorm
hours ran a median of 2090. That takes the same year from 8 storm hours to 28,
and 5 storm days to 13, with no frontal-rain hour wrongly promoted.

**A storm is the same three layers as ordinary cloud, exaggerated.** Same three
heights, lobes roughly doubled (28 / 20 / 14 against 14 / 10 / 7), coverage
forced to full so all three always draw and a storm can never be mistaken for
an overcast hour. Drawn in the same pass as the ordinary decks, so it occludes
in the same order: the low layer reaches 78, above both the mid base at 50 and
the high base at 70, and cuts into them.

It is drawn per RUN, like the decks, not per hour, so a long storm is one
continuous three-layer mass. Two earlier attempts were rejected on device: an
anvil, which read as a diagram inside a drawing; and a single big radial blob,
which scalloped all the way round and floated with a lumpy underside instead of
sitting on a base like every other cloud.

**The three decks move at three rates, by position.** High at 0.85, mid at
0.93, low at 1.0, with the arc as the reference so nothing on the line ever
drifts. No spring: the layers are locked to the wheel, since a trailing spring
read as lag rather than as depth.

Each deck is scaled horizontally about the time dot, not merely offset more
slowly, and that is the whole trick. A plain slower offset drifts without bound
-- the error grows with distance from the layer's origin and reaches around
700pt for the high deck part-way through a day, so the upper sky would show the
wrong hour's weather entirely. Scaled about the dot, the error is
(1 - factor) x distance from the dot: zero under the dot, at most about 29pt at
the screen edge, on any hour, with no jump at day boundaries. The 15% horizontal
squash on the high deck comes free and reads as distance.

The sky had to move out of the cached arc layer for any of this; ArcContent now
owns only the curve, the baseline and the ticks.

**Lightning does not flash yet.** A flicker was built and removed, to come back
to later. The storm's static wash stays.

**Weather overrides the time of day.** A storm sky is not also a sunset sky, so
the twilight wash fades out in proportion to how much weather is present.

**The weather wash is weighted to the top of the screen** and clears before the
arc block begins. Darkening the band would cost the arc and the clouds their
contrast, and they cannot be recoloured per frame without giving up the cached
layers. Overhead is where weather belongs anyway.

**The title and the caption each hold a fixed contrast against the measured
ground.** Title 9:1, caption 3.5:1, derived by mixing the designed colour rather
than picking a neutral grey, so the ink keeps its warmth. This CAPS as well as
raises: on a clear day the ink measures 15:1 and is deliberately brought down to
9:1. That is the price of uniformity and it lands on the most-seen screen of
all; the alternative, letting the title run free while the caption was pinned,
is what let the two meet at dusk and read as one weight.

The measured ground is everything painted over the background at the top of the
screen, in draw order: twilight, then rain, then storm. Leaving twilight out of
it was a real bug -- at full dusk the ground is 0.386 while the code reported
1.000, so the caption sat at plain grey and measured 1.4:1, while heavy rain at
the same real luminance got 6.2:1 because rain was the only thing counted.

Gap spread is now 1.60x to 2.57x, against 1.00x to 4.29x before. The one
remaining variance is the storm, where the ground physically cannot support 9:1
in any direction and the title takes the best available, 5.6:1.

**All the washes share one set of stops**, weighted to the top of the screen and
gone before the arc block, so twilight reads as sky in the same way weather
does rather than as a tint over the whole screen.

**Rain and storms wash the ground, as dawn and dusk do.** Rain darkens it to
slate, a storm darkens it further with the flash low down where the cloud base
is. Both follow the FOCUS hour, so they agree with the dot and with the twilight
wash, and both sit over twilight since weather is nearer than the time of day.
Readings are hourly, so the strengths are interpolated between the two hours
either side; without that a wash snaps on and off at hour boundaries while the
wheel turns.

**Rain is a curtain, not ticks.** Hatching hangs between the cloud base and the
arc, leaned by wind, with density and length from millimetres.

**A clear hour still draws a wisp**, so an empty band always means "no data" and
never "nothing in the sky". Sun and moon marks are gone from the band; the time
dot is the only celestial body.

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
