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

**Lightning does not flash.** A flicker was built, tried and rejected. The
storm's static wash stays.

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

**All-day events live under the header, not in the menu.** They have no hour and
cannot sit on the arc, so they get their own button below the date caption,
showing the single title when there is one and a count when there are more. The button is a clock and the phrase "X all day", always counted even at one,
at the caption's own size. Its row is RESERVED whether or not the day has any:
letting it appear and vanish shifted the whole arc down and back while scrubbing
across a day with a birthday on it, and squeezed the title.

It opens a sheet with ONE detent, so it cannot be dragged open: it is a glance,
not a list view. Each row opens the same Apple editor a timed event uses.

The clock's hands carry the hour the wheel is on and sweep as it turns, the same
idea as the time dot. Two hands in a plain circle: at caption size a tick face
reads as a grey ring rather than as ticks.

The menu opens at full height only, one detent. Its date, place and sun material
is one BLOCK, not a linear list: the place in display type with the date picker
opposite it on the same line, the search and the location action under that, then
a rule and a MINI ARC of today, with sunrise, midday and sunset marked on the
curve and a dot where the real day has got to. Three timestamps make you do
arithmetic to picture a day; the arc is the picture, and it reads better here
than on the main screen, where 24 hours spread over eight screen widths is
locally almost flat.

The sheet's sun, moon and weather are anchored to the real NOW, not to the
wheel, so they stay a reference for the actual day however far the wheel has
wandered. The corner beside the city carries tonight's moon and the temperature
and condition right now; hourly temperature is fetched in celsius and localised
at the point of display. The place carries its state or region, so Chicago reads
as "Chicago, IL".

Switches and pickers tint with `ControlAccent`, not `Ink`. In dark mode ink is
nearly white, and a near-white track under a white knob makes a toggle read as
one solid white pill with no visible state. A two-card grid and a tightened list were built,
compared on device and removed.
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

## Event editor: three separate faults behind one report (2026-09-01)

Tapping an all-day event took ten seconds to open, and editing it did nothing.
Instrumented on device with a trace that survives a launch; three unrelated
causes.

**Opening was slow.** The tap dismissed the all-day sheet and set the editor
target in the same tick. UIKit will not present over a sheet still on its way
out, and SwiftUI does not call `updateUIViewController` again on its own, so the
target sat dropped until an unrelated re-render happened along — 10.3s in the
trace, and variable. `EventEditorHost` now waits for the presentation to clear,
bounded at two seconds. Tap to editor is ~600ms.

**Deleting never called the delegate.** `EKEventEditViewController` commits a
delete to the store and skips `didCompleteWith` entirely; saving and cancelling
both call it. One trace holds a working save and a broken delete three seconds
apart through identical code. The editor stayed open over an event that was
already gone, and nothing reloaded until relaunch. `closeIfEventDeleted` treats
`EKEventStoreChanged` as the completion signal: if the event being edited no
longer exists, close and reload. This is the same bug as the earlier timed-event
delete, which the move to a real presenting controller did not actually reach.

**Saving did nothing, and that one was correct.** The event under test was
created by Gmail with the user as an attendee, so EventKit refuses the write —
Calendar.app refuses it too. The containing calendar still reports
`allowsContentModifications = true`, which is why it looked like a defect. The
discriminator is the organizer: an event you own has none
(`organizer == nil`), one you were invited to has `organizer.isCurrentUser ==
false`. Sphere's actual fault is opening a working-looking editor on an event
that can never save. Treatment still to decide.

## Existing events open in Apple's detail view (2026-09-01)

`EKEventViewController`, the view Calendar.app shows, replaces going straight to
the editor for any event that already exists. New events still open in
`EKEventEditViewController`, since there is nothing to view yet.

The reason is that editability is not ours to determine. With `allowsEditing`
set, iOS decides whether an Edit button appears, and withholds it on read-only
and subscribed calendars and on events someone else invited you to — cases the
organizer check alone would miss. It also carries RSVP, so an invitation is
something you can act on rather than a dead end.

The cost is one extra tap to edit an event you own, including from the centre
button. Taken knowingly: the alternative was reproducing Apple's rule ourselves
and being wrong at the edges.

### Amended the same day: branch instead of routing everything through it

Routing every existing event through `EKEventViewController` drew two Delete
Event rows on one screen. `EKEventEditViewController` is itself a
`UINavigationController`, so inside the navigation controller the detail view
needs, Edit pushed rather than presented and both screens rendered into one.

So the split is by editability after all: your own events open the editor
directly, and only an event EventKit would refuse goes to the read-only detail
view, with `allowsEditing` off so nothing can nest. The extra tap on your own
events goes away with it.

`isEditable` is the calendar's `allowsContentModifications` plus the organizer:
an event you created has no organizer, an invitation names someone who is not
you. Both signals were confirmed on device — your own all-day event reported no
organizer and no attendees, the Gmail-created one reported an organizer that is
not you and one attendee.

## Haptics, behind one setting (2026-09-01)

The wheel has no travel and no sound, so turning it read only as the numbers
above it changing. A detent every quarter hour gives it the click the drawing
implies: sixteen to a rotation at four hours per turn, close to the hardware it
borrows from and far enough apart to stay a texture.

Clicks are counted against the focus hour, not against rotation, so turning
slowly and turning fast click at the same places on the day, and a turn crossing
several at once still clicks once — a burst per frame reads as a buzz.

Jumps get a weightier tap on arrival: a chevron, the arc tapped to return to
now, a day picked. It sits in `travel` rather than at the four call sites, for
the same reason the capsule suppression does — written separately, one of them
ends up silent. It fires only when the focus actually moved, so pressing NOW
while already on now stays quiet: that is a no-op, not an arrival.

The chevrons' dead end gets a blunter, sharper tap again. When nothing exists
within forty-five days the dot cannot move, and that was previously silent and
indistinguishable from a missed tap.

Three weights, so the wheel has a vocabulary rather than one buzz: light for a
detent, medium for an arrival, rigid for a wall.

One switch in the menu, on by default: the wheel is the app's main control and
shipping it mute would hide the feature from anyone who never opens settings.

## DATE forks; the arc stops carrying a gesture (2026-09-01, superseded same day)

Returning to now was a tap on the arc, chosen because the arc is the one surface
big enough to carry a gesture nothing can label. Unlabelled was the cost:
nothing on screen said the day was tappable, so the fastest move in the app was
the one you had to be told about.

DATE now opens a two-row fork, Now or Calendar, both printed. Each destination
costs one tap more than before, and neither has to be discovered.

Each row shows what it is offering — the clock time you would land on, against
the day you are already looking at — so the fork carries the information the
choice is actually made on.

The calendar path runs from the sheet's `onDismiss`, not from the binding
flipping: the binding flips while the fork is still on its way out, and
presenting into that is the refusal that cost the event editor ten seconds
earlier the same day.

## The wheel is programmable (2026-09-01)

The fork sheet is reverted. It cost a tap every single time; a setting costs one
tap once, which is the argument that decided it.

Every position now carries a fixed tap and one assignable hold. Taps are the
wheel's vocabulary and do not move: a printed word that can come to mean
something else stops being readable. Holds carry nothing printed, which is
exactly why they are safe to reassign.

The pool is NOW, Calendar, Previous day, Next day, and None. Creating an event
and opening the menu already own a position each, so putting them in would hand
out duplicates rather than access. Day-stepping is the one genuinely new
capability: the chevrons' tap lands on an event, their hold lands on the same
clock time a day either side.

Shipped mapping: bottom taps NOW and holds Calendar, and setting one sets the
other, so neither can be orphaned the way the arc tap was. Chevrons hold to step
a day. MENU and the centre have hold slots that ship empty, because inventing a
second meaning to fill a slot is worse than a slot that admits to being empty.

A hold is invisible in the way the arc tap was invisible. The settings wheel is
the answer to that: a copy drawn in the wheel's own line and proportions, at
three fifths the size, printing every position's tap and hold whether or not it
can be changed. Its first job is documentation, not configuration. Tapping a
position there selects it rather than performs it — settings is not a place
where the day should move under you.

A `Button` cannot hold both gestures: a long press over one fires the press and
then the action on release. Built from `onTapGesture` and `onLongPressGesture`
directly, SwiftUI resolves them. The hold pays out the moment it registers
rather than on release, with its own light haptic, since a hold that only landed
when the thumb lifted felt like a slow tap.

## The centre holds to make an all-day event (2026-09-01)

Tap makes a thirty-minute event at the wheel's hour, hold makes an all-day one
on the focused day. It is the same rule the chevrons follow: tap is the
fine-grained thing, hold is its day-scale twin.

It also closes a gap. There was no way to create an all-day event anywhere in
Sphere, and the header row only appears once one exists, so nothing offered to
make the first.

Start and end land on the same date, which is what Calendar.app writes for a
single all-day event and what the editor reads back as one day rather than two.

MENU's hold stays empty pending a decision on what belongs there.

## MENU holds light/dark; the pool grows to nine (2026-09-01)

MENU is the one position the day-scale rule does not reach, since its tap is
app-scale rather than time-scale. Its hold is app-scale too: tap opens the
app's settings, hold flips its most-used one. Empty was a placeholder held only
while there was nothing worth putting there.

Light/dark lands on an explicit setting rather than cycling back through
system. Reaching for a manual toggle is already a statement that you do not
want it decided for you, and the menu is where system is chosen again.

Four actions joined the pool: light/dark, search, open in Calendar, mute
haptics. None of them are duplicates of a tap, which stays the test for
admission.

Search is the first route to an event the arc cannot reach. The chevrons see
forty-five days and the arc draws three. A year either side is the window where
the fetch stays fast enough to filter on every keystroke; past that it needs
paging, which is where building more on search starts. It is currently
reachable only by assignment, which makes it as invisible as the arc tap was,
so it likely needs a permanent home of its own eventually.

## One pool per position, not one pool (2026-09-01)

The wheel is not a flat list of five slots. The time positions move the day and
should only accept actions that move the day; MENU is app-scale and should only
accept app-scale ones. A wheel where mute haptics could sit on a chevron has
five slots and no shape.

- Chevrons: now, calendar, previous day, next day, new all-day event, none.
- MENU: light/dark, search, open in Calendar, mute haptics, none.
- Centre: fixed to new all-day event. Its tap makes events and its hold makes
  the day-scale kind, and nothing else belongs there.
- Bottom: fixed to whichever of now/calendar its tap is not.

A pool that narrows leaves old assignments behind, so a stored hold no longer
offered for its position falls back to that position's default rather than
staying set to something settings can no longer show.

Hold threshold is 0.25s, down from 0.35s. Below about a fifth of a second taps
and holds start trading places.

## Bespoke marks, drawn in the arc's line (2026-09-01)

Three variants were built and switched live: words only, SF Symbols at
ultraLight, and hand-drawn marks. Bespoke won.

Drawn at 1.3 stroke with round caps and joins, in a 20-point box, no fill
except where a dot is the point. That is the same family as the sky marks, one
step lighter than the arc's 1.5.

Days are arcs here, so the marks say it that way: NOW is the arc with its time
dot, stepping a day is a run of three arcs with an arrow on the end, opening in
Calendar is a day with an arrow leaving it. The one exception is the calendar
itself, a grid of dots four across and three down, because the universal shape
reads faster there than restating the app's would.

Known limit: iOS context menus render only text and `Image`, so the marks
cannot appear inside the picker dropdowns. They sit in the printed rows. If the
marks are wanted in the picker too, the picker has to stop being a system menu.
