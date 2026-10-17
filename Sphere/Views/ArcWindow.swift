import SwiftUI

/// A pinchable slice of an unbounded timeline, 1.5 hours to about 5 on an iPhone 17 and
/// persisted between launches. The dot is nailed to the centre
/// of the screen and never moves; three days of arc slide underneath it, so
/// crossing midnight needs no separate control and no seam.
struct ArcWindow: View {
    let model: DayModel
    /// Every capsule is held back while a jump is in flight, not just the
    /// destination: the others sweep across the screen too, and that is most
    /// of what a long jump looks like.
    var eventsHidden = false
    var arcHeight: CGFloat = 190
    /// How dark the sky is, and READ BY NOTHING in this file as of 2026-10-13. It used to be
    /// what the marks above the horizon lightened with; `skyInk` is now plain `mark`, and the
    /// comment on it 270 lines below says why. `ContentView` passes a literal 0 and records that
    /// the parameter is kept on purpose rather than torn out, so this is a parked input, not a
    /// live one. Anything above the horizon changes with `mark` and with nothing else.
    var nightness: Double = 0
    /// Weather takes precedence over night, the way it did over dusk. Also read by nothing here,
    /// for the same reason and since the same date.
    var nightSuppressedBy: Double = 0
    /// Black or white, decided by the field and passed down to everything drawn on it.
    ///
    /// REQUIRED, with no default, since 2026-10-10. It defaulted to `.black`, which was correct
    /// only because the app's own screen always computes a mark from the sky behind it. The
    /// onboarding's arc never passed one, inherited black, and drew a black curve, a black sun
    /// and black hour labels on `Theme.background` — invisible in dark mode, and shipped that
    /// way. A default is a promise that one value suits every caller, and here it suited one.
    let mark: Color

    /// Drag the arc to scrub time. Reported upward in HOURS rather than applied here, so the
    /// model write and the detent haptics stay in one place. Nil leaves the arc inert, which is
    /// what the onboarding demo wants.
    var onScrub: ((Double) -> Void)?
    var onScrubBegan: (() -> Void)?

    /// A tap, reported as the ABSOLUTE HOUR under the finger. What is there decides what the
    /// caller does with it: empty time creates at that time, an event asks New or Open. Reported
    /// as an hour rather than acted on here, because the arc knows where the finger landed and
    /// nothing else does.
    ///
    /// Swapped to return-to-now for one build on 2026-10-09 and swapped back the same night. A
    /// tap carries a location for free; the hold needed a second gesture running alongside just
    /// to learn where the finger was, which is a cost paid for the action that needs it least.
    var onTapTime: ((Double) -> Void)?
    /// Pinch changes how much day is on screen. On the canvas rather than on any object, which
    /// is where a pinch belongs: both fingers can land anywhere.
    var onZoom: ((Double) -> Void)?

    /// Hold asks Menu or Guide (2026-10-14, reordered 2026-10-16), which is the same pair the
    /// corner's menu mark opens and the same sheet. No location needed, which is why it is the one that holds: it
    /// had the time sheet for a single build on 2026-10-10 and gave it back to the tap, which
    /// knows where the finger is; it then carried Now and Menu for a day; and the two things on
    /// it now are the two surfaces that care least where the finger was. Now went back to the
    /// tap's sheet the same day.
    var onHold: (() -> Void)?
    /// A tap inside either edge band steps to the next or previous EVENT, -1 back and +1 forward.
    /// It stepped a whole day for one build on 2026-10-10 and changed the same day: the edges are
    /// where you reach when what you want is off-screen, and what is off-screen that you want is
    /// an event, not a date.
    var onEdgeStep: ((Int) -> Void)?

    /// How wide the edge bands are, measured in from each edge. 44 points is the smallest target
    /// Apple will call reachable, and it is the most that can be taken from tap-to-create: at the
    /// default window on an iPhone 17 it is 20 minutes of the day at each end, and 33 at the
    /// widest zoom (Mason, 2026-10-10, told the cost and took it).
    static let edgeBand: CGFloat = 44

    /// Live drag state, kept local on purpose. The parent learns hour deltas, never the finger's
    /// position, and `translation` is cumulative so each callback sends only what is new.
    @State private var lastTranslation: CGFloat = 0
    @State private var isScrubbing = false
    /// Set when the long press fires, consumed by the tap that follows it on lift.
    ///
    /// The two gestures are independent and both are allowed to win. `LongPressGesture` succeeds
    /// at 0.45s with the finger still down, which is the feel the guide's press ring teaches, and
    /// then `onTapGesture` recognises the same touch when it lifts — SwiftUI's tap has no maximum
    /// duration. So one long press raised the hold's sheet AND the tap's, and the two `.sheet`
    /// modifiers fought over which got presented (Mason, 2026-10-14: "both modals open up (or
    /// compete to open)").
    ///
    /// Composing them as `LongPressGesture().exclusively(before:)` is the structural fix and was
    /// not taken: it means replacing `.onTapGesture` with a gesture in the same arena as the
    /// scrub's `DragGesture(minimumDistance: 8)`, and this file has lost that fight twice — the
    /// `contextMenu` starvation of 2026-10-03, and the reason `minimumDistance` is 8 and not 0.
    /// A flag cannot starve anything.
    @State private var didHold = false
    /// The window the pinch started from. Magnification is relative to the gesture's start, so
    /// without this each callback would compound into a runaway zoom.
    @State private var zoomBase: Double?

    var body: some View {
        GeometryReader { proxy in
            let pointsPerHour = proxy.size.width / model.windowHours
            let dayWidth = 24 * pointsPerHour
            let firstDay = model.dayIndex - 1
            let originHour = Double(firstDay) * 24
            let centreX = proxy.size.width / 2
            let pan = centreX - (model.focusHour - originHour) * pointsPerHour
            let dotY = ArcGeometry.y(normalized: model.normalizedElevation(atAbsoluteHour: model.focusHour), height: arcHeight)

            ZStack(alignment: .topLeading) {
                // The clip moved off this stack and onto the two groups that
                // actually pan, so the night between them can reach above the
                // block and cover the header's sky as well.
                ZStack(alignment: .topLeading) {
                // Each day is its own cached layer, so only the set of three
                // changes when the drag crosses a boundary. Panning never
                // re-samples a path.
                HStack(alignment: .top, spacing: 0) {
                    ForEach(firstDay...(firstDay + 2), id: \.self) { index in
                        ArcContent(day: model.solarDay(index), width: dayWidth, height: arcHeight, mark: mark)
                            .equatable()
                    }
                }
                .frame(width: dayWidth * 3, alignment: .topLeading)
                .offset(x: pan)
                }
                .frame(width: proxy.size.width, height: ArcGeometry.totalHeight(arcHeight),
                       alignment: .topLeading)
                .clipped()

                // Over the curve, the ticks and the labels; under the sky. The
                // fill's edge IS the curve, so covering the line it is drawn
                // from is what makes it read as an edge of the world rather
                // than a shape laid over one.
                ZStack(alignment: .topLeading) {
                // Each deck is its own layer so it can trail the arc by its own
                // amount. Further decks lag more, which is the parallax; they
                // catch up the moment the drag stops, so a cloud is never
                // permanently off its hour.
                ForEach(SkyContinuous.Deck.allCases) { deck in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(firstDay...(firstDay + 2), id: \.self) { index in
                            ZStack(alignment: .topLeading) {
                                // Behind the deck's own drawing, so a cloud
                                // filling with the background covers what is
                                // meant to be behind it.
                                ClearSky(
                                    day: model.solarDay(index),
                                    width: dayWidth,
                                    height: arcHeight,
                                    hours: model.sky(forDayIndex: index),
                                    daySeed: index,
                                    deck: deck,
                                    skyInk: skyInk,
                                    skyGround: skyGround,
                                    blinkStep: Int(model.focusHour * 8)
                                )
                                .equatable()

                                SkyContinuous(
                                    day: model.solarDay(index),
                                    width: dayWidth,
                                    height: arcHeight,
                                    hours: model.sky(forDayIndex: index),
                                    daySeed: index,
                                    deck: deck,
                                    skyInk: skyInk,
                                    skyGround: skyGround
                                )
                                .equatable()
                            }
                            // Top-aligned and at the FULL height. Without the
                            // alignment this centred 322pt of sky in a 190pt
                            // box and pushed every deck 66pt up into the
                            // window's clip, which cut the tallest storms off.
                            .frame(width: dayWidth,
                                   height: ArcGeometry.totalHeight(arcHeight),
                                   alignment: .topLeading)
                        }
                    }
                    .frame(width: dayWidth * 3, alignment: .topLeading)
                    // Scaling horizontally about the dot is what makes this
                    // work. A plain slower offset drifts without bound: the
                    // error grows with distance from the layer's origin and
                    // runs to hundreds of points across a day. Scaled, the
                    // error is (1 - factor) x distance from the dot, so it is
                    // zero under the dot and at most about 29pt at the screen
                    // edge, whatever hour you are on.
                    //
                    // The 15% horizontal squash on the high deck comes free
                    // with it, and reads as distance rather than as a defect.
                    .scaleEffect(x: deck.parallax, y: 1, anchor: .leading)
                    .offset(x: pan * deck.parallax + centreX * (1 - deck.parallax))
                }

                EventLayer(
                    events: model.timedEvents,
                    originHour: originHour,
                    pointsPerHour: pointsPerHour,
                    width: dayWidth * 3,
                    height: arcHeight,
                    activeID: model.activeEvent?.id,
                    elevation: { model.normalizedElevation(atAbsoluteHour: $0) }
                )
                .offset(x: pan)
                .opacity(eventsHidden ? 0 : 1)

                Rectangle()
                    .fill(Theme.hairlineSoft)
                    .frame(width: 1, height: max(0, ArcGeometry.baseline(arcHeight) - dotY))
                    .position(x: centreX, y: (ArcGeometry.baseline(arcHeight) + dotY) / 2)

                TimeDot(
                    mark: mark,
                    elevationDegrees: model.elevationDegrees(atAbsoluteHour: model.focusHour),
                    moon: model.focusMoonPhase,
                    ceilingDegrees: model.focusSolarDay.seasonalCeiling
                )
                .position(x: centreX, y: dotY)
                }
                .frame(width: proxy.size.width, height: ArcGeometry.totalHeight(arcHeight),
                       alignment: .topLeading)
                .clipped()
            }
            .frame(width: proxy.size.width, height: ArcGeometry.totalHeight(arcHeight), alignment: .topLeading)
            // STUDY: scrub by dragging the arc. `minimumDistance` is 8 rather than 0 so the taps
            // this surface is about to carry — create at a time, open a capsule, step to an
            // event at either edge — still get their touch. A zero-distance drag would swallow
            // all three. (That list read "return to now" until 2026-10-13; the tap stopped
            // carrying Now on 2026-10-10 and the comment did not notice.)
            .contentShape(.rect)
            .gesture(scrubGesture(pointsPerHour: pointsPerHour), isEnabled: onScrub != nil)
            // The bands come first: inside one, the tap is an event step and never a time.
            // Outside them it is the inverse of the pan above, so at centreX it is exactly
            // `focusHour`.
            .onTapGesture { location in
                guard pointsPerHour > 0 else { return }
                // The lift at the end of a long press arrives here as a tap. Swallow exactly one,
                // the one belonging to the press that just fired.
                if didHold {
                    didHold = false
                    return
                }
                if let onEdgeStep, location.x <= Self.edgeBand {
                    onEdgeStep(-1)
                } else if let onEdgeStep, location.x >= proxy.size.width - Self.edgeBand {
                    onEdgeStep(1)
                } else {
                    onTapTime?(originHour + (location.x - pan) / pointsPerHour)
                }
            }
            // Guarded on the drag: a long drag is not a long press. Holding still for 0.45s
            // asks Menu or Guide; moving first makes it a scrub and nothing fires. (It read
            // "returns to now" until 2026-10-13, which was true until 2026-10-10 and then was
            // not: the hold went to the menu that day, to a pair three days later, and to the
            // corner's pair on 2026-10-14.)
            //
            // `didHold` is what stops the lift from also counting as a tap; see its declaration.
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in
                        guard !isScrubbing, lastTranslation == 0 else { return }
                        didHold = true
                        onHold?()
                    },
                isEnabled: onHold != nil
            )
            // Spread to see more of the day, squeeze to come back in. Simultaneous with the
            // scrub so a pinch that drifts does both rather than fighting.
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        let base = zoomBase ?? model.windowHours
                        if zoomBase == nil { zoomBase = base }
                        // Spreading magnifies, and spreading should show MORE hours, so the
                        // window divides rather than multiplies.
                        let range = DayModel.windowRange(forWidth: proxy.size.width)
                        onZoom?(min(max(base / value.magnification, range.lowerBound),
                                    range.upperBound))
                    }
                    .onEnded { _ in zoomBase = nil },
                isEnabled: onZoom != nil
            )
        }
        .frame(height: ArcGeometry.totalHeight(arcHeight))
    }

    /// Drag right to go back in time, the direction the arc itself moves.
    private func scrubGesture(pointsPerHour: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if !isScrubbing {
                    isScrubbing = true
                    lastTranslation = 0
                    // A drag is a new touch, so any unconsumed hold belongs to a finished one.
                    // Without this, a press whose lift landed on the sheet rather than on the arc
                    // would leave the flag set and swallow the next real tap.
                    didHold = false
                    onScrubBegan?()
                }
                // Deltas, not the cumulative translation: sending the total each callback would
                // compound it into an accelerating slide.
                let delta = value.translation.width - lastTranslation
                lastTranslation = value.translation.width
                guard pointsPerHour > 0 else { return }
                onScrub?(-delta / pointsPerHour)
            }
            .onEnded { _ in
                isScrubbing = false
                lastTranslation = 0
            }
    }

    /// One pair for the whole window: at every zoom it is a few hours wide, so the difference
    /// between its edges is not worth redrawing three cached layers for.
    /// Clouds, birds and stars are marks like any other: black or white, never between. This
    /// read `Theme.skyInk(nightness:)` and `nightness` is hard-zero since the shaped night went,
    /// so at night it would have drawn near-black outlines on a near-black field (2026-10-09).
    private var skyInk: Color { mark }

    /// What a cloud fills with to cut a hole in the deck behind it — the sky's
    /// own colour, not the paper's, or the clouds punch white holes in a night.
    /// A cloud's BODY, and the thing a nearer deck cuts a hole in a farther one with. It must
    /// contrast with the field or the cloud vanishes: filling it with `sky` made every cloud
    /// invisible by construction, since that is exactly the colour behind it (2026-10-09).
    /// The opposite pole from the marks — white clouds under black outlines by day, black
    /// clouds under white outlines at night.
    private var skyGround: Color { mark == .black ? .white : .black }
}
