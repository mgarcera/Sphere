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
- ~~**Monetization**, which decides whether Open-Meteo's non-commercial free tier
  is enough or WeatherKit is needed.~~ Closed 2026-09-02: the app is not being
  monetized, so the free tier stands and WeatherKit is not needed. This is also
  what makes a widget fetching its own forecast a live option rather than a
  licensing question.
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

iOS context menus render only text and `Image`, so the marks could never appear
inside a system picker. The picker stopped being one: choosing happens inline,
underneath the row, so the mark being picked sits beside the one already set.

`Mark` is kept apart from `WheelAction` so that giving MENU a picture does not
put "menu" in the pool a hold can be set to. Every tap has one: a hamburger for
MENU, a capsule for an event, and for the four directional marks one
construction — arrows, a straight line, then that line rising into a day. One
arrow steps an event and two step a day. Count carries the whole distinction,
which survives the sixteen-point row where a difference in lobe counts did not.

Icons on the wheel were tried behind a switch and removed. The printed words
are the reference the whole control is built on, and marks made the four
compass points lumpy where words gave them equal weight. The marks stay where
they earn their place, in settings, naming actions that have no room for a
word. The haptics switch stays in the Wheel section, since it belongs to the
wheel.

Restricting each position to its own pool is settled: the wheel keeps its shape
and the lists stay short enough that grouping them would be scaffolding around
nothing.

## The picker has no open state (2026-09-01)

Every choice for the selected position is listed, always. Nothing to open, and
the option in force reads at full strength while the rest sit back at a third.
The brightness is the state, so there is no tick or radio to add and no
duplicate readout in the row above: a row with choices shows only its gesture
label, and a fixed one prints what it does.

They are ranged right, under the value they replace, so the mark being chosen
lands in the same column as the mark already set.

Icons instead of words drives the settings diagram as well as the wheel. A
setting whose preview does not obey it is worse than no preview.

Reset clears the stored keys rather than writing the current defaults back, so
a position whose default later changes follows the new one instead of staying
pinned to whatever shipped the day it was reset. It is behind a confirmation
and disabled while nothing has been moved: it undoes every position at once and
nothing on screen reads back what was there before.

## A clear sky draws stars and birds (2026-09-02)

An empty band was indistinguishable from weather that never loaded, which is
what the clear-sky gap actually was. Stars are the honest half: they are
visible precisely when it is clear. Birds are the whimsical half and are not
pretending to be data.

Stars belong to the high deck and birds to the low one, and the middle deck
draws neither. A bird at star altitude is the one thing that reads as wrong
rather than as stylised.

**Density is a rate per clear hour, not a budget per day.** A budget put the
same few birds into a two-hour clearing and a fourteen-hour one, so how dense
they looked on screen depended on what fraction of that day happened to be
clear. The window is three hours wide and that is the only unit anyone
experiences. Grouping and a dawn/dusk weighting were both built and tried
against even spacing; even spacing won, because a clearing you scroll into
should have birds in it rather than a chance of birds.

**Nothing animates on a clock.** The twinkle is driven by the scrub position,
quantised to seven and a half minutes of scrolled time, so an idle screen is
perfectly still and the cost is bounded by how fast a thumb can turn.
Everything else in the app moves because the wheel moved. Stars dim to half
rather than vanishing: a star that disappears takes a piece of the field's
arrangement with it. Birds never twinkle, so their decks build no clock and
never redraw while the wheel turns.

Marks are cached per day, deck and forecast. Their positions never depend on
the scrub, so the hashing and trigonometry happen once per day rather than on
every redraw; without that, winking on the scroll would have cost exactly what
winking on a clock did.

Each bird is caught at a different point in a wingbeat. Tip drop and wing bow
move opposite each other, so none comes out as a flat tick.

Three bugs found on the way, all of them mine, all worth remembering:
a cache key that left out the weather froze an empty sky from the first render;
a density roll salted from a counter that only advanced on a placement gave
every hour the same answer once one came up empty; and a frame with a height
but no alignment centred 322pt of sky in a 190pt box, pushing every deck 66pt
up into the window's clip and taking the tops off the storms.

## A place carries its clock (2026-09-02)

Picking Bakersfield while sitting in Chicago put sunrise, midday and sunset two
hours late. Not a formatting slip: `utcOffsetHours` is used inside the elevation
function as well as in the sunrise and sunset formulas, so the whole arc was
being drawn on the device's clock. At longitude −119 that puts solar noon at
14.9h rather than 12.9h, which is exactly the two hours observed.

The old behaviour was self-consistent and answered a real question, "when does
the Bakersfield sun do things, on my clock." It just is not the question anyone
asks. The app now travels: the picked location's timezone drives the sun, the
arc's day boundaries and every date shown against it.

This is also right in the case the picker was built for. When it is correcting
your own location, that timezone is already the device's, so nothing changes.

A timezone now rides with every location — from `MKMapItem.timeZone` for a
searched place, `CLPlacemark.timeZone` for a typed one or a device fix — and is
persisted with the coordinate. A coordinate without its clock is what caused
this.

`relocate` preserves the instant being looked at rather than the clock hour.
Rebuilding the anchor without that would leave `focusHour` counting from a
different midnight and jump the dot by the difference between the zones.

A fix's coordinate arrives before its timezone, since the zone comes back from
the geocoder a moment later, so the relocation is triggered by either changing.

## The centre button asks when there is something to ask (2026-09-02)

Inside an event, opening it was the only thing on offer, so an hour that
already held something could not have anything else put in it. Real days nest:
a call inside a block, a break inside a shift.

The centre button now forks only where a fork exists. In empty time it still
creates in one tap. On an event it offers Open against New, two printed columns
rather than one of them being a hidden gesture, with the event's name under one
and the hour under the other so the choice carries what distinguishes it.

This is the two-column sheet that was built for NOW against Calendar and
reverted when the wheel became programmable. It belongs here instead: that fork
was a permanent tax on a frequent move, this one appears only in the rare case
where the button is genuinely ambiguous.

The chosen action runs from the sheet's `onDismiss`, not from the binding
flipping, since presenting the editor into a sheet still on its way out is the
refusal that cost ten seconds once already.

The bottom button reads CAL rather than DATE when it is set to the calendar.

## The lens actually refracts (2026-09-02)

A ring over an unchanged arc reads as a circle, not as glass. Glass is
recognised by what it does to what is behind it, so the arc inside the lens is
the arc redrawn through one.

The mapping is the standard thin ball-lens one: a source point `d` from the
centre appears at `r = R sin(n asin(d/R))`, with `n` about 1.5 for glass. Only
the disc within `R sin(π/2n)`, about 0.87R, is visible through it, and that
disc is spread across the whole lens — which is the magnification, 1.5x at the
centre. Curvature grows toward the rim, so the arc bends as it nears the edge
and steps where it meets the arc outside. That step is the thing that says
glass.

The interior is cleared to the background before the refracted copy is drawn,
or the unrefracted arc shows through its own magnification.

Native options were checked and are the wrong tool. `distortionEffect` and
`layerEffect` warp a rendered view through a Metal shader, which means a
`.metal` file and a rasterised result for what is otherwise a crisp vector at
any size. `glassEffect` refracts what sits *behind* a view, not a drawing
inside it. Warping the path is simpler, sharper and has no dependencies.

New is a plain plus. The lens beside it already says event, so restating that
in the second mark only made the pair rhyme.

## The lock screen, and the shared layer under it (2026-09-02)

A widget runs in its own process with none of the app's services: no event
store, no location manager, no forecast. So `Shared/` became a synchronized
group belonging to both targets, holding the solar math and one snapshot
struct.

Only the inputs travel. The sun is arithmetic, so the coordinate and its
timezone go across and the curve never does. The next event does go across as
a result, since a widget has no event store unless it asks for calendar access
of its own, and one permission prompt is enough for one app.

The timeline hands over eight hours in ten-minute steps at once. A widget gets
a few dozen reloads a day and most of them would be spent on a position that
can simply be calculated, so precomputing costs nothing and moves the dot
smoothly. Only the next event goes stale, and the app reloads the timeline
whenever it changes.

The accessory arc is drawn for its size rather than shrunk from the app. The
main arc is 24 hours across roughly eight screen widths, so locally it reads
nearly flat; the same day squeezed into a lock-screen accessory becomes a
proper hill, which is the only reason it is legible that small.

Two traps in the project file, both silent. A nested dictionary cannot be
expressed as a flat `INFOPLIST_KEY_`, so `NSExtensionPointIdentifier` was
dropped and the extension shipped with no extension point at all — it built
and signed, and only failed at install. And an `Info.plist` inside a
synchronized folder is copied as a resource as well as being the target's
`INFOPLIST_FILE`, which collides; it lives outside that folder now.

Still to do: the App Groups capability. `xcodebuild` cannot add it, so the
entitlements files exist but are not referenced and the widget currently reads
nothing.

## The home screen, and a palette both targets can reach (2026-09-02)

The lock screen accessory needed no colours: its rendering mode flattens
everything to vibrancy. A home widget does, so the ten colorsets moved to
`Shared/Palette.xcassets` and `Theme.swift` with them. The app icon and the
accent colour stayed behind in `Sphere/Assets.xcassets`, since an extension
carrying an app icon is a submission warning waiting to happen.

Same arc, same capsules, same stem, in ink rather than white. What changes with
size is the context around it: small carries the next event, medium adds where
you are and when the sun comes and goes. Sunrise and sunset sit under the curve
they belong to, so the arc is labelled rather than annotated.

The sky is not there. Weather is not in the snapshot, and putting it there is a
second payload with its own staleness; the drawn clouds are the obvious thing
to add to a large widget once that exists.

## A Live Activity for the event you are in (2026-09-02)

An activity has to be bounded and the system ends one after about eight hours.
An event supplies its own bound, so that is the shape: started when an event
contains the real now, ended when it stops doing so.

It watches `eventContainingNow`, not `activeEvent`. The wheel wanders and the
activity is about what is happening, not about what is being looked at.

**A drawn mark cannot animate itself.** A Live Activity redraws only when a new
content state is pushed, and pushing from the background needs remote
notifications. So the arc is static for the length of the event, which is
correct — the day does not change while one event runs — and everything that
must move is handed to the system: `Text(timerInterval:)` counts down with no
updates at all. The dot moves when the app is running to push it, and its
position simply holds otherwise.

The minimal presentation is one dot at the height the sun actually is. It is
the whole app at its smallest, and the only thing that fits in that space that
still means something.

### Amended the same day: no countdown, and an overview instead

A number falling towards zero is the one thing that turns a calm surface into
a deadline, and nothing else in this app ticks. The countdown is gone from the
lock screen, the compact presentation and the expanded one. Where it stood
there is now the event's span, which states the same fact without counting
down to it.

So the activity shows the whole day with every event on it and the current one
picked out, rather than reporting on one event. The day travels in the content
state rather than the attributes, since a day can gain an event while one is
still running.

That is also honest about what a Live Activity can do. It redraws only when a
new state is pushed, so anything that had to move by itself would have to be
the system's own timer — which is exactly the ticking thing.

Where nothing is coming, the widgets say nothing. A place name in that space
was filling a line rather than carrying information, and an empty day should
look empty.

## The sun decides light and dark (2026-09-02) — REMOVED 2026-09-03

"Auto" is "System", which is what it always was: the device's setting. The
fourth mode is the app's own, and it reads the sun's elevation — the same
number the arc's height comes from, so sunrise needs no trigger of its own. It
is simply where that crosses zero.

**It follows the wheel, not the real now.** The alternative was to anchor it to
the actual moment, the way the menu's sun, moon and weather are anchored. That
would be the calm choice and it is the wrong one here: the whole screen is a
drawing of the hour you are on, and scrubbing into the evening while the screen
stays bright is the app disagreeing with itself. Now the surface goes over with
you. The menu's material stays anchored to the real now, because that block is a
reference for the day rather than a picture of the hour.

A threshold at zero would strobe. The wheel can be parked on a crossing and
jogged, so the mode holds what it last decided inside half a degree either side
of the horizon — about the sun's own width, and two minutes of a day. That
memory lives in the view, since the enum is a value and has nowhere to keep it.

The name is Sun, over Daylight, Solar and Sundial. System, Light and Dark each
name the authority that decides; this one names its authority too, and it is the
app's own word. It is the only one of the four that needs a line under it, since
it names its source rather than its effect.

The wheel's light/dark action still lands on an explicit setting, but it now
computes what is on screen from the resolved scheme rather than from the system
one, or flipping out of Sun would have landed on whatever the device happened to
be doing.

## Weather on a large widget, built and removed (2026-09-02)

**Removed the same evening, on the device.** The sky at widget scale looked
strange: the drawing that reads as weather across eight screens does not survive
being asked to hold a whole day in one, whatever the lobes and standoffs are
tuned to. The large family went with it, since the sky was the only thing it had
that a medium does not. The shared moves, the scale, and the forecast in the
snapshot came out too: none of them had another caller, and an unused file with
no reason on it is drift.

What follows is what was built, kept because the next attempt at this should
start from it rather than rediscover it.



The sky is the whole reason the large family exists. Everything else the tile
shows fits in a medium; the decks need vertical room that medium does not have.

**The drawing is shared, the scale is not.** `SkyContinuous`, `ClearSky`,
`SkyMarks` and `ArcGeometry` moved to `Shared/`, and a `SkyScale` moved with
them. Shrinking everything by a third would have given five-point clouds under a
stroke still a point and a third wide, which reads as scribble. So the decks
come in, the lobes get WIDER in hours — 24 hours across a widget is 14 points an
hour, and a lobe measured in hours has to grow to stay a cloud — and the stroke
comes down to a point. Same code, same hand, different size: the rule the lock
screen accessory set.

`ArcGeometry` became a value to make that possible. The app reads it off the
type exactly as before; the widget builds one shaped like `HomeArc`'s own box,
full height at peak over `arcHeight - 3`, or the clouds would follow a curve the
visible arc never takes.

**The forecast rides in the snapshot.** It is the one thing a widget cannot work
out from a coordinate and a clock, and unlike the next event it is not a single
fact, so it is the only real payload in there: about forty-eight hours at a few
hundred bytes each. Two days, because a timeline runs eight hours forward and
crosses midnight, and each day carries the day it belongs to.

It also carries when it was fetched. Past twelve hours, or on a day the app
never wrote, the sky is left out rather than guessed at — a forecast for the
right day is still a forecast, but half a day after it was fetched it is the
app's memory of the weather rather than the weather.

The widget's own network fetch was the other option and is not needed for this:
Open-Meteo is a keyless GET and a timeline provider may make one, but it wants
its own cache for offline and its own copy of the provider layer, for freshness
the app's own launches mostly supply.

## The sun mode is parked (2026-09-03)

Taken out of the app, tag `palette-experiment`, along with everything that grew
out of it. Appearance is System, Light and Dark again, on the asset catalog,
exactly as it was before.

What the branch established, so the next attempt does not rediscover it:

- **A scheme switch cannot be made soft by covering it.** Extending the twilight
  wash so both schemes composite to the same dusk at the crossing hid the
  ground and left the ink snapping, which is most of what you look at.
- **The crossing cannot be dodged at all.** Ink starts darker than the ground
  and ends lighter, so their luminances must meet, and at that instant a mark is
  the colour of what it sits on. No pair of continuous curves avoids it.
- **So it has to be spent, not avoided**: every mark holding its designed
  contrast against the moving ground, crossing one at a time on its own
  schedule, over a ground that runs through a warm dusk rather than through
  grey, and quickly. That version measured at most two faint marks at any
  instant against nine, and read as very close on the device.
- **What was left unsolved** is the header. The title and the caption sit on the
  wash rather than on the background, and holding a contrast ratio through the
  crossing pushes them back to full strength on either side of it — so they snap
  while the drawing dissolves. The last thing tried was letting the hold give
  way to the mark inside the turn.

The whole line of work is one `git revert` of this commit away.

## The widgets draw the calendar's colours (2026-09-03)

The home widget was drawing every capsule in `TaskInactive`, a flat blue that
belongs to nothing: the app draws each event in its calendar's own colour, at
full strength for the one you are in and 0.72 for the rest. The widget was the
only place that disagreed.

So the colour travels. `SnapshotEvent` carries components — `Color` is not
`Codable` and the group container is JSON — and it is optional, so a snapshot
written before this decodes and falls back to the flat colour rather than
going blank. The Live Activity reads the same payload, so it picked the
calendars up too.

The lock screen accessory does not, and cannot: its rendering mode flattens
everything to vibrancy. That is the one place the flat colour was never the
problem.

**The arrow was tried and dropped.** The wheel's next-event mark went into the
widget in place of the word, then to the end of the title in full ink, and it
was a look worth seeing rather than one worth keeping: in a widget the mark has
no wheel around it to mean anything against. The word stands. `ActionMark` came
back out of `Shared` with it, since nothing outside the app draws a mark now.

**The medium widget gave up the sun's times.** Sunrise and sunset were a pair of
readings under a curve that already draws both; the row they cost is worth more
as a second line of title. Both families now take two lines.

## The span replaces the label, and the menu's arc gets its day (2026-09-03)

**"Next" is gone from the widgets.** The word said what the position already
says — it is the only thing at the top of the tile — and the span is the fact
that was missing. Under the title now: "2:30 – 3:15 PM", with the meridiem
printed once where both ends share it, since "2:30 PM – 3:15 PM" is the same
fact said twice. An event that is not today carries "Tomorrow," or its weekday,
because a start time alone on an empty afternoon reads as sooner than it is.
The end travels in the snapshot for it, optional like everything else there, so
an older snapshot prints the start alone rather than nothing.

**The menu's moon and temperature moved down to the arc.** They were up beside
the place name, which is where the sheet says WHERE; they belong with the thing
that says WHEN. The row above the arc now reads "TODAY" on the left and the moon
and the temperature on the right, and the arc draws the day's events as capsules
in their calendars' colours, at the widgets' two strengths — full for the one
happening now, 0.72 for the rest. The arc was already the picture that saves
three timestamps from being arithmetic; the events are what it was missing.

**Today, decided.** The toggle between today and the wheel's day is gone: the
label is TODAY and the arc is today's. Everything outside the main arc is about
now — the sheet's sun, moon and weather already were, and one thing following
the wheel in a block anchored to the real hour was the odd one.

### One arc, three places (2026-09-03)

The menu's arc was drawing its curve in INK at 1.3 while both widgets drew
theirs in `MutedLight` at 1.4 — so the same picture read as a different object
in each place, and in the menu the ground competed with what was on it. The
curve is `MutedLight` everywhere now.

Weights are aligned and split further apart. The curve came down to 1.1 in all
three, and the capsules went up to 3.4, with 5 for the one happening now — the
accessory keeps 3, since vibrancy and its own size do some of that work. What
matters is the gap between the two: the curve is what the day is drawn on, the
capsules are what is on it, and a point of difference was not enough to say so.

For the record, since it was asked: the home widget and the Live Activity draw
horizon `Hairline` 1, curve `MutedLight`, capsules in the calendar's colour at
1.0 and 0.72, stem `HairlineSoft` 1, dot `Ink`. The lock screen accessory has no
palette at all — vibrancy flattens it — so it is white at 0.25 for the ground,
0.40 for the curve, 0.55 for the capsules, 0.45 for the stem and full white for
the dot.

### Now only, and read from the store (2026-09-03)

The wheel was leaking into the widgets. Their events came from
`model.timedEvents`, which holds a day either side of the FOCUS, so scrubbing
three days out published a snapshot with nothing for today in it and the tiles
went empty. The menu's small arc had the same fault from the same source.

Both read the store directly now, for the day they draw: the snapshot takes
today and tomorrow, which is what a timeline running eight hours forward can
reach, and the menu takes today. `CalendarService.timedOccurrences(from:to:)` is
the one place that asks. The Live Activity shares the snapshot's list rather
than mapping its own, since it is about now as well.

The rule this settles: **the arc is the only thing that follows the wheel.**
Everything else — widgets, the activity, the menu's readings and its arc — is
about the real now, whatever is being looked at.

## The week strip, built and dropped (2026-09-03)

Seven circled dates under the title, Sunday to Saturday, following the wheel:
the selection springing between dots, a changed week arriving one column at a
time, a tap to land on a day and a hold for the date picker. Seen on the phone
and dropped — the written line reads better in that spot. The caption is
"Thursday, September 3" again, with the active event's span after it.

Kept here because the mechanics are the part worth not rediscovering. The strip
had to animate from held `@State`: the wheel moves `focusHour` with no
transaction, so a transition reading a computed value off it is attributed to
nothing and never runs. The numbers needed `.contentTransition(.identity)` or
they crossfaded into each other as the week slid. And the stagger belonged on
the way IN only — a delay reads as sequence when several things arrive together
and as lag when one thing leaves alone.

The commit is `dc2bbdb`, one revert away.

## Fog is a field, and the sky gets a line (2026-09-03)

The old fog was the weather ICON for fog: three straight lines, evenly spaced,
centred, one stamp per hour. Three replacements were built and compared on the
phone — long broken wisps drifting across the whole bank, the same wisps with
ends dissolving rather than stopping, and a density field of very short dashes
thickest mid-bank. The field won, and the other two are stripped along with
their picker.

Nothing in it is long enough to read as a stroke, which is the point: the mass
reads as haze where a line reads as a line. Deterministic per day and hour like
every other mark, so it does not shimmer while the wheel turns.

**The sky now says what it is.** Under the all-day row: the mark, the word and
the temperature in whole degrees — "Clear 71°". It follows the WHEEL, unlike
the widgets and the menu, because the clouds directly above it are drawn for
the focused hour and a reading anchored to the real now would contradict the
picture it sits under. The row is reserved whether or not the forecast has
arrived, for the reason the all-day row is: a line that appears later shifts
the whole arc.

The condition is not blended across the hour the way precipitation is. A
condition is a word, and half of "rain" is not a word.

The menu's corner carries the same three things in the same order, and both
round to whole degrees.

## The one request that leaves rounds first (2026-09-04)

An audit of every data flow in the app, for the privacy policy the App Store
needs, turned up one thing worth changing rather than describing.

Open-Meteo is the only non-Apple host this app talks to, and it was being handed
`String(coordinate.latitude)` — the raw Double off CoreLocation, unrounded.
`kCLLocationAccuracyKilometer` is a hint about the FIX, not a cap on what gets
sent, so the request carried a doorstep where the app only ever needed a
neighbourhood. Two decimals is about 1.1km, matches what the app asks
CoreLocation for, and is finer than the forecast grid the answer comes off, so
nothing on screen changes.

The fix itself stays precise. The sun's arc is computed on device and wants
every digit; it is only the outbound copy that is coarsened.

What the audit confirmed, for the policy: no analytics, no crash reporting, no
third-party SDK, no dependency manifests, and exactly one non-Apple host in
6,250 lines. Calendar titles never leave the device. Location is When-In-Use,
one-shot, never appended to a history.

What it caught that the policy must not overclaim: the app takes FULL calendar
access and reads a year of events into memory for search, it WRITES to the
calendar through Apple's own editor, reverse geocoding and place search send
fixes and keystrokes to Apple, one real event title is drawn on the lock screen
by the widget and the Live Activity, and `UserDefaults` — which holds a manual
place's coordinate — travels in device backups.

## A way to say something back (2026-09-04)

Fil and Weeklite both carry the same in-app feedback sheet — sentiment, a
message, an optional email — posted to Formspree, which turns it into an email.
No account, no backend, no key. Sphere now carries it too, at its own form,
since each app has its own.

Ported rather than reinvented: same fields, same payload, same alerts. What
changed is the register — system type on the app's own ink, and the fields drawn
as hairline rectangles rather than filled cards, because nothing else here is a
card.

**It makes Formspree the second thing this app talks to.** Until now the privacy
story was one non-Apple host receiving a rounded coordinate. It is now two, and
the second carries what a person typed plus the app version, device model, iOS
version and a timestamp. That has to be said in all three places — the manifest,
the App Store questionnaire, and the policy page — before this ships.

Worth noting for the other two apps: **neither Fil's nor Weeklite's privacy
policy mentions the feedback form at all**, and Fil's says "the ONLY time
anything leaves your device is if you subscribe to Fil Extra and run a smart
search", which the sheet contradicts every time someone uses it.

## Now, drawn as a plane (2026-09-07)

A visual counterpart to the NOW button, and the design turns on one decision:
**the plane is not near now, it IS now.** It sits at the real hour, high above
the cloud decks, so its position on screen answers "where is now from here"
without a word. Everything else falls out of that. The heading needs no bearing —
it faces the way it is travelling relative to you, which is home. The tap needs
no special case — you fly to the plane, and the plane is where now lives.

**It does not tick.** Nothing in this app moves on its own clock; the stars wink
off the scrub and the countdown was cut for the same reason. So the plane moves
because the wheel moved, and a still screen stays perfectly still. That killed
the obvious version — a plane crossing on a timer — and the version that
replaced it is better, because a mark pinned to now is information where a mark
crossing on a schedule is decoration.

Absent while you are home: its presence is the message. Absent in a storm:
planes route around weather, and a mark competing with lightning loses.

The parallax is 0.35, against the high deck's 0.85, and the number is not a
taste call. It decides how long the plane is on screen. At 0.7 it left the
screen two hours out and then spent the whole fade invisible — full opacity,
nothing to see. At 0.35 it reaches the edge at about four and a half hours,
which is exactly where the fade finishes: it goes and it disappears in the same
moment. The arithmetic caught that before the device did.

One drawing, day and night — no branch, nothing to keep true twice. Top-down,
because that is the only view this app can honestly have of an aircraft, with a
contrail that says direction and speed while nothing moves.
