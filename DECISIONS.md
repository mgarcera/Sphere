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

## Still open

- **All-day events.** They have no hour and cannot sit on the arc. Going in a
  small modal opened from a navbar button. The navbar does not exist yet and has
  not been designed. The brief says "one screen, no navigation stack in v1",
  so this is a change to that too.
- **Overlapping events** need a tiebreak for the header title. Implemented as
  shortest-wins, since a standup inside a focus block is what you are actually
  doing, but never confirmed.
- **Where the planetary hours live**, now that both the arc tinting and the
  tarot cards are gone.

## Carried over from the brief, unchanged

- Location is still hardcoded to Chicago. Core Location or a city picker is
  still open.
- Ascendant/Midheaven and the Equal House system are still unverified against a
  reference ephemeris.
- Personal mode, the natal chart and transits are untouched by any of the above.
