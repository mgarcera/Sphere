<!--
DRAFTED 2026-09-11 against the app as it stands at 45bd999. NOT yet pasted into ASC.

Every capability claimed below was checked against the source, not against the brief.
`PRODUCT_BRIEF.md` is stale: it describes a planetary-hours task app with a local `DayTask`
type and a natal chart. `DECISIONS.md` overrides it, and this file follows DECISIONS.

Deliberately absent from the copy, because the code does not ship them:
- Planetary hours. `Planet` still holds the seven call-to-action lines and nothing renders them.
- Personal mode, the natal chart and transits. `Model/Chart.swift` compiles; no view reads it.
- Event search. Taken out at 9499cb6. The only search that ships is the place field in the menu.
- The large home widget and the sky on a widget. Built and removed 2026-09-02.
- Snow in the sky band. `SkyCondition.snow` has a header glyph only; nothing falls.
-->

# Sphere — App Store Listing Metadata

*Copy these into App Store Connect. Character counts are noted; Apple's limits in parentheses.
Verify counts in ASC (it's the source of truth).*

> **No rejection history.** Sphere has never been submitted. The one rejection this file inherits is
> Fil's: **5.2.5, Intellectual Property**, where the subtitle read `Lock screen & dynamic island`.
> Apple allows referential use of a feature trademark in a description's prose and not in the **name
> or subtitle**. Sphere's name and subtitle name no Apple feature at all, which is the cheapest way
> to stay clear of that clause. "Home Screen" and "Lock Screen" appear in the
> description as prose and nowhere in the name, the subtitle or the keyword field.

- **App name** (30): `Sphere: Sky Schedule` — 20 chars. Colon, not an em dash, for the reason Fil's
  carries one: the dash renders cramped at App Store card sizes and the colon reads as a label.
- **Subtitle** (30): `Your day on the sun's arc` — 25 chars. This is already the app's line in two
  other places, the site's hero and the priming screen's title, so the listing agrees with both.
  `Calendar on the sun's arc` (also 25) was the ASO-stronger alternative: subtitle carries the
  second-highest search weight and "calendar" is the app's one head term. Rejected because the
  keyword field can carry "calendar" for 9 of its 100 characters, and the tagline cannot be bought
  back once three surfaces disagree.
- **Primary category:** Productivity   ·   **Secondary category:** Weather
  Productivity is where calendars are searched for. Weather is not decoration on the secondary slot:
  the sky band is drawn hour by hour from a real forecast, and the app fetches cloud cover by
  altitude, precipitation, wind and CAPE to draw it.
- **Bundle ID:** `com.smidgecraft.Sphere` on team `T89Z7YKXVC` (Mason Garcera, individual). The
  widget extension follows the namespace at `com.smidgecraft.Sphere.widget`, and the app group is
  `group.com.smidgecraft.Sphere`. App Groups is the only capability either target needs; both
  entitlements files are referenced by `CODE_SIGN_ENTITLEMENTS`, which they were not on 2026-09-02.
- **Price:** Free. **No in-app purchases, no subscription.** Monetization closed 2026-09-02: the app
  is not monetized, which is what keeps Open-Meteo's free tier sufficient and WeatherKit unnecessary.
- **Devices:** iPhone only (`TARGETED_DEVICE_FAMILY = 1`), portrait only, iOS 26.0 minimum. No iPad
  screenshots are required and none should be uploaded.

## Keywords (100, comma-separated, no spaces)
```
calendar,agenda,event,planner,widget,sunrise,sunset,daylight,weather,forecast,cloud,timeline,today
```
98 chars. Hidden from users; they carry the search load while the name and subtitle carry the
positioning.

**Deliberately absent, because the name and subtitle already index them:** `sphere`, `sky`,
`schedule`, `day`, `sun` and `arc`. Apple stems, so `sun` is indexed from the subtitle's `sun's`
and singulars cover plurals — which is why `event` and `cloud` are singular here.

Also absent on purpose: `app`, `free`, and the category words. Apple's own guidance ignores them,
and each costs characters a long-tail term could use.

## Promotional text (170)
```
Sphere draws today as the sun's own elevation curve for where you are, lays your calendar along it, and puts the hour's forecast in the sky above the line.
```
155 chars. This is the only listing field that stays editable after a version is approved, so it is
where a seasonal line or a "new in 1.1" note goes without waiting for review.

## Description
```
Sphere draws today as a single line: the sun's real elevation curve for where you are and the date you are on. The hill is taller in summer and shallower in winter because the sun really does go higher. Your calendar lies along that line, each event a capsule running from its start to its end, in the color of the calendar it came from.

Above the line is the sky for the hour you are on, drawn from the forecast rather than from a set of icons. Cloud decks stack by altitude, so cirrus draws above cumulus and a nearer deck cuts into the one behind it. Rain hangs as a curtain between the cloud base and the ground, leaned by the wind. Storms are found from atmospheric instability rather than from a weather code, so a real thunderhead shows up as one. A clear hour gets a blue read off a photograph of the sky, with stars at night and birds by day.

A click wheel moves the day. One rotation is four hours, with a small haptic detent every quarter hour, and turning past midnight carries into the next day or the previous one. Sphere has one screen and no navigation stack.

- The center button makes an event at the hour the wheel is on. Hold it for an all-day one.
- The chevrons step to the next and previous event. Hold either to step a whole day.
- Every position's hold can be reassigned, and the settings screen is a drawing of the wheel that prints what each position does.
- Events open in Apple's own editor, so editing, deleting and replying to an invitation work exactly the way they do in Calendar.
- All-day events sit under the date, where they can be read without taking room on the arc.

Natural Sky is the appearance setting. The app is light by day and dark at night and it turns at the horizon, on the same number the arc's height is drawn from. Dark is there for anyone who wants a dark app at noon, which the sun cannot give them.

Outside the app:

- Home Screen: the day's arc with your events on it, in small and medium.
- Lock Screen: where the sun is, and what is next.

The menu holds the rest: a place to work from, today's arc with sunrise, midday and sunset marked on it, tonight's moon and the temperature right now, and a switch for each calendar you want on the line.

Sphere is free. No account, no subscription, no ads, no analytics, no tracking.

Your calendar stays on your device. Sphere asks for full calendar access because it creates and edits events as well as reading them, and for your location because the arc is the sun's curve for a place. One thing leaves: a coordinate rounded to two decimal places, about a kilometer, sent to Open-Meteo to ask what the sky is doing. It travels on its own, with no name, no identifier and nothing from your calendar. Event titles are never sent anywhere. The feedback form in the menu sends what you type into it along with the app version and device model, and your email address only if you choose to give one.

Privacy: https://smidgecraft.com/sphere/privacy
Support: https://smidgecraft.com/sphere/support

Questions, ideas, or feedback? mason@smidgecraft.com
```

Every claim above is traced to code:
`ArcGeometry`/`SolarDay` (the curve and the 65% peak cap), `EventLayer` (capsules in the calendar's
color), `SkyContinuous` and `WeatherProvider` (decks by altitude, occlusion, CAPE-driven storms),
`ClearBlue`/`ClearSky` (the measured `65A2E4`, stars, birds), `ClickWheel` + `Haptics` (four hours a
rotation, a detent every quarter hour), `WheelSettings`/`WheelAction` (reassignable holds),
`EventKitSheets` (Apple's editor and detail view), `AllDaySheet`, `Theme.Appearance` (Natural Sky and
Dark, and no third option), `SphereWidget/` (accessoryRectangular, systemSmall, systemMedium), `DayMenu`/`MiniArc` (the place field, today's arc, the moon and temperature, the
per-calendar switches), `WeatherProvider.coarse` (two decimals), `FeedbackSheet` (the payload).

## What's New (version 1.0.1) — 2026-09-21
```
Calendar
- Deleting a recurring event, including all future events, now closes the editor and updates the day right away.

Thank you for using Sphere! Feedback: mason@smidgecraft.com
```

## What's New (version 1.0)
```
the first Sphere. your day drawn as the sun's own arc, your calendar laid along it, and the hour's weather in the sky over the line. turn the wheel to move through the day, hold a button to step a whole one. widgets for the home and lock screen.

free, no account, nothing to buy. tell me what to build next: mason@smidgecraft.com
```

## Also set in App Store Connect

- **Legal entity / copyright:** `Mason Garcera`. Set the app's copyright to `© 2026 Mason Garcera`.
  `INFOPLIST_KEY_NSHumanReadableCopyright` is currently an empty string and should be filled to
  match.
- **Seller name:** ⚠️ comes from the developer account enrollment, not an ASC field. On an
  individual account it shows the enrolled person's legal name, so the listing will read
  **Mason Garcera**, not Smidgecraft, unless a trade name is approved by Apple. Same open question
  as Fil's.
- **Support contact email (App Review Information):** `mason@smidgecraft.com`.
- **Privacy Policy URL:** `https://smidgecraft.com/sphere/privacy` (must match
  `SphereLinks.privacyPolicy`).
- **Support URL:** `https://smidgecraft.com/sphere/support` (must match `SphereLinks.support`).
- **Terms of Use (EULA):** leave ASC on Apple's Standard License Agreement. Sphere has no terms page
  of its own and no subscription, so there is nothing a custom EULA would carry.
- **In-app purchases:** none. Nothing to attach to the version, and nothing to write about in the
  description.
- **Export compliance:** `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` is already declared in
  the project, so the per-upload prompt is skipped. Confirm the ASC answer agrees.
- **Age rating:** no objectionable content, expected 4+. The questionnaire is still Mason's to answer.
- **Small Business Program:** enroll the individual account. Commission is moot on a free app with no
  purchases, but enrollment is worth having before anything is ever sold.

### App Privacy questionnaire — one answer, three places

The privacy manifest, the ASC nutrition labels and the policy page must say the same thing. What
they say now:

- **Coarse Location**, used for **App Functionality**, **not** linked to identity, **not** used for
  tracking. This is the coordinate sent to Open-Meteo, rounded to two decimals in
  `WeatherProvider.coarse` before the request is built. `kCLLocationAccuracyKilometer` is a hint
  about the fix, not a cap on what is sent, which is why the rounding is explicit.
- **Nothing else is collected.** No analytics, no crash reporting, no third-party SDK, no dependency
  manifest. The 2026-09-04 audit found exactly two non-Apple hosts in the whole app: Open-Meteo, and
  Formspree when someone taps Send on the feedback form.
- **Feedback** carries what the person wrote, the sentiment if they picked one, the app version,
  device model, iOS version, a timestamp, and an email address only if they supply one. It carries
  nothing from the calendar and nothing from the location. Declare it under the categories ASC
  offers for user content and contact info, both **App Functionality**, both **not** used for
  tracking. It is not in `PrivacyInfo.xcprivacy` today; the manifest declares only coarse location.
- **Calendar** data never leaves the device, so it is not a collected type. The access is still full
  read and write, because events are created and edited in the app.
- `UserDefaults` is declared with `CA92.1` (the app's own settings) and `1C8F.1` (the app-group
  snapshot the widgets read), in both the app's and the widget's manifests.

The live policy at `/sphere/privacy` already names Open-Meteo, the two-decimal rounding, Apple's
geocoding and place search, and the Formspree form by name. It is the one of the three Smidgecraft
policies that does mention the feedback form; Fil's and Weeklite's still do not.

## App Review Information

- **Sign-in required:** No. Sphere has no accounts and nothing is gated.
- **Contact:** Mason Garcera · mason@smidgecraft.com · (phone as entered in ASC)
- **Demo account:** none needed.

### Notes — paste verbatim

```
No account is required. Open the app and it works immediately.

PERMISSIONS
Sphere asks for two things on first launch, both behind one explanation screen shown before the
system prompts.

Full calendar access: the app lays the reviewer's events along the sun's arc as capsules, and the
center button of the wheel creates events and opens Apple's own EKEventEditViewController to edit
or delete them. Read-only access would make the app unable to do half of what it is for. If access
is refused, the app still draws the day, the sun and the sky; the line is simply empty.

Location, when in use: the arc IS the sun's elevation curve for a place, so without a coordinate
there is no drawing. If location is refused, Sphere falls back to Chicago and says so, and the
place field in the menu lets anyone type or search a city instead. To test the app without granting
location, open the menu and search for any city.

WHAT LEAVES THE DEVICE
Two non-Apple hosts, and that is the whole list.
1. Open-Meteo, a keyless public weather API, receives a latitude and longitude rounded to two
   decimal places (about one kilometer) and returns the hourly forecast the sky band is drawn from.
   Nothing else is attached: no identifier, no device information, nothing from the calendar.
2. Formspree, a form-to-email service, receives a feedback message only when the user taps Send in
   the menu's feedback form. It carries the message, an optional sentiment, the app version, device
   model, iOS version and a timestamp, plus an email address only if the user enters one.
Apple's own services receive a coordinate for reverse geocoding and the text typed in the place
field for search suggestions. Calendar titles and times never leave the device.

HOW TO MOVE THROUGH THE APP
The click wheel is the only navigation. Drag around it to scrub through the day; one full rotation
is four hours and turning past midnight moves to the next or previous day. MENU opens settings.
The chevrons jump to the next and previous event, and holding one steps a whole day. The bottom
button returns to now. The center button creates an event at the hour the wheel is on, and holding
it creates an all-day event.

EXPECTED BEHAVIOR THAT MIGHT LOOK LIKE A BUG
The whole app changes from light to dark at the moment the sun crosses the horizon, as a cut with
no animation. That is the "Natural Sky" appearance setting and it is the default. Setting
appearance to Dark in the menu stops it. There is deliberately no "follow the system" option.

The sky band is empty when no forecast is available for the hour on screen. An empty sky means
"not known", never "clear"; a clear hour draws a blue with stars or birds in it.

The widgets read a snapshot the app writes into its app group, so they show a placeholder until
the app has been opened once.
```

## UNVERIFIED — Mason to confirm

These are not in the repo, or could not be settled from the code. Nothing above asserts them.

1. **SKU.** Never shown to anyone, never reusable, and not editable after creation. Match whatever
   convention Fil and Weeklite used on this account.
2. **App name availability.** `Sphere: Sky Schedule` is unique across the entire App Store or it is
   not, and that is only discovered at record creation. Have a second choice ready before opening
   the form.
3. **The priming screen has no way past it.** `CalendarPriming` renders while
   `calendar.access == .undetermined` and offers one button, Continue, which fires the system
   prompts. There is no skip, so a reviewer who does not tap Continue never reaches the app. This is
   the exact shape of **5.1.1(iv)**, the clause Fil was rejected under for a priming sheet with no
   dismissal path. Refusing at the system prompt is fine (access becomes `.denied` and the app
   proceeds); never tapping Continue is the stuck state. Decide before submitting whether Continue
   alone is enough or the screen needs a second way out.
4. **Age rating questionnaire.** Expected 4+, but the answers are Mason's to give.
5. **Screenshots.** None exist in the repo. Required: iPhone 6.9" at 1320 × 2868. No iPad set is
   needed, since the app is iPhone-only.
6. **The widget does not follow Natural Sky in 1.0.** It reads the asset catalog, so on a light-mode
   phone at night the app is dark beside a light widget. Recorded in DECISIONS as narrow, visible
   and accepted. It is not mentioned in the description; confirm that is the right call rather than
   a line in What's New.
7. **Feedback-form data types in the ASC questionnaire.** The privacy manifest declares only coarse
   location. Whether Formspree feedback needs its own entry in `PrivacyInfo.xcprivacy` as well as in
   the ASC labels is a judgment call about a user-initiated message, and it is worth settling once
   for all three apps rather than per app.
8. **Open-Meteo's free tier.** It is the non-commercial tier, which stands only while Sphere is free
   with no purchases. Any future paid version or in-app purchase makes WeatherKit the second
   `WeatherProvider` conformer, which the protocol already anticipates.

---

## Removed before submission (2026-09-14)

The **Live Activity** is out of 1.0 — code, the `NSSupportsLiveActivities` key, and every line of
this listing that promised it. A description that claims a surface the binary does not have is a
rejection rather than a typo, which is why this was done before any screenshot was shot against it.
