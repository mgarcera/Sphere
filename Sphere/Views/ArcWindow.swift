import SwiftUI

/// A three-hour slice of an unbounded timeline. The dot is nailed to the centre
/// of the screen and never moves; three days of arc slide underneath it, so
/// crossing midnight needs no separate control and no seam.
struct ArcWindow: View {
    let model: DayModel
    /// Every capsule is held back while a jump is in flight, not just the
    /// destination: the others sweep across the screen too, and that is most
    /// of what a long jump looks like.
    var eventsHidden = false
    var arcHeight: CGFloat = 190
    /// How dark the sky is: the night's own strength, and what the marks above
    /// the horizon lighten with.
    var nightness: Double = 0
    /// Weather takes precedence over night, the way it does over dusk.
    var nightSuppressedBy: Double = 0
    /// Black or white, decided by the field and passed down to everything drawn on it.
    var mark: Color = .black

    /// STUDY (2026-10-09): drag the arc to scrub time, the direct version of what the wheel does
    /// by rotation. Reported upward in HOURS rather than applied here, the same shape
    /// `ClickWheel` uses for `onRotate`, so the model write and the detent haptics stay in one
    /// place. Nil leaves the arc inert, which is what the onboarding demo wants.
    var onScrub: ((Double) -> Void)?
    var onScrubBegan: (() -> Void)?

    /// STUDY: a tap, reported as the ABSOLUTE HOUR under the finger. One callback covers two
    /// actions because what is under the finger decides which: an event opens, empty time
    /// creates. The wheel's centre button could never express this — it had to infer a time from
    /// the focus, where a tap carries one.
    /// Tap opens what is under the finger, or creates there on empty time. Reported as the
    /// ABSOLUTE HOUR, which is the thing a wheel could never say: the centre button had to infer
    /// a time, a tapped point carries one.
    ///
    /// Swapped to return-to-now for one build on 2026-10-09 and swapped back the same night. A
    /// tap carries a location for free; the hold needed a second gesture running alongside just
    /// to learn where the finger was, which is a cost paid for the action that needs it least.
    var onTapTime: ((Double) -> Void)?
    /// Hold returns to now. No location needed, which is why it is the one that holds.
    var onHold: (() -> Void)?

    /// Live drag state, kept local on purpose. The parent learns hour deltas, never the finger's
    /// position, and `translation` is cumulative so each callback sends only what is new.
    @State private var lastTranslation: CGFloat = 0
    @State private var isScrubbing = false

    var body: some View {
        GeometryReader { proxy in
            let pointsPerHour = proxy.size.width / DayModel.windowHours
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
                // changes when the wheel crosses a boundary. Panning never
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
                // catch up the moment the wheel stops, so a cloud is never
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
            // this surface is about to carry — create at a time, open a capsule, return to now —
            // still get their touch. A zero-distance drag would swallow all three.
            .contentShape(.rect)
            .gesture(scrubGesture(pointsPerHour: pointsPerHour), isEnabled: onScrub != nil)
            // Inverse of the pan above: at centreX this is exactly `focusHour`.
            .onTapGesture { location in
                guard pointsPerHour > 0 else { return }
                onTapTime?(originHour + (location.x - pan) / pointsPerHour)
            }
            // Guarded on the drag: a long drag is not a long press. Holding still for 0.45s
            // returns to now; moving first makes it a scrub and nothing fires.
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in
                        guard !isScrubbing, lastTranslation == 0 else { return }
                        onHold?()
                    },
                isEnabled: onHold != nil
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

    /// One pair for the whole window: it is three hours wide, so the difference
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
