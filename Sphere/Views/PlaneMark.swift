import SwiftUI

/// Now, drawn as a plane.
///
/// Built once before and taken out on 2026-09-07; the decision record kept what that established
/// and this inherits all of it. Three things from there govern what is here:
///
/// **The plane is not near now, it IS now.** Pinned to the real hour, so its position on screen
/// answers "where is now from here" with no words and no bearing.
///
/// **Nothing in this app moves on its own clock.** The plane moves because the window moved. It
/// never crosses on a timer, which was the obvious version and the wrong one.
///
/// **There is no parallax any more, and the question it answered is gone with it.** Both earlier
/// versions sat the plane on a fraction of now's travel — 0.7, then 0.35 — which meant the mark
/// was never quite over the time it reported, and a whole derived quantity (`fadeHours`) existed
/// only to work out where that drift put it off-screen. Mason took it out on 2026-10-21: the
/// plane sits exactly on now. It therefore reaches the edge precisely when now leaves the window,
/// there is no exit distance left to compute, and the fade is a plain function of how close to
/// the edge it is.
///
/// What is new this time (Mason, 2026-10-21):
///
/// **It always noses forward.** The first version turned toward home, which meant it flipped
/// direction depending on which side of now you had scrubbed to — a mark reporting a bearing
/// nobody asked it for. Always toward later reads as travel rather than as a readout.
///
/// **It is the highest thing in the drawing, at every zoom.** Nothing in the sky is ever above
/// it: not the high deck, not a storm crest, not the stars. `lift` is computed from
/// `SkyMarks.ceiling` for exactly that reason, so the plane rises and falls WITH the weather
/// rather than against it as the first two versions did.
///
/// It briefly answered the sun's height as well, riding the curve at now, and that was wrong in
/// the way a mark is wrong rather than the way a number is: at midnight the curve is under the
/// horizon line, so the plane flew underground. It now holds one cruising line per day — see
/// `DayModel.todayPeakElevation` for why that line is the day's own peak and not a fixed height.
///
/// **The shape is his, not ours.** The first pass hand-drew a plane and he rejected it on sight.
/// What ships is `PlaneShape`, traced from the line art he supplied and verified against it at
/// 97.66% IoU, so the only thing left for us to choose is how heavy the ink sits — `inkBoost`
/// below. Redrawing it by hand is how we got the 1.7:1 plane; the aspect now comes off the
/// trace and cannot drift.
/// **Its attitude answers the zoom as well.** Zoomed in it lies along the arc's own slope at
/// now, so it reads as travelling the curve; zoomed out it returns to the climb the drawing was
/// made with, nose up over the collapsed weather. The two ends are the same gesture as `lift`,
/// and they are driven by the same `zoomScale`.
struct PlaneMark: View {
    /// The attitude the artwork already carries, in screen coordinates with y down.
    ///
    /// Measured off the traced ink, not chosen. The fuselage's lower edge runs -15.04 degrees
    /// across five sampled columns in the 40 x 13.35 display frame. The ink's principal axis
    /// reads -11.37, but the wing's horizontal spread flattens that, and it is the fuselage the
    /// eye takes as the plane's attitude. Negative is nose up.
    static let drawnAttitude: Angle = .degrees(-15.04)

    /// How high it flies above today's peak, in points.
    ///
    /// It measured from the curve at now until 2026-10-21, which meant the altitude fell with
    /// the sun and put the plane 6.7 points BELOW the horizon line at midnight. It now measures
    /// from `DayModel.todayPeakElevation`, a line that does not move through the day, so this is
    /// a cruising altitude rather than a following distance.
    ///
    /// It runs WITH the sky, not against it (Mason, 2026-10-21 — the plane "should never be at
    /// the level of birds or storm clouds, it should be the highest element"). The earlier
    /// 28-to-104 ramp ran the other way, and since everything in the sky scales by `zoomScale`
    /// too, that put the plane at its LOWEST exactly when the clouds were at their tallest: 28
    /// above the curve against a storm crest at 143.7, so it flew 116 points inside the weather
    /// at the three-hour window.
    ///
    /// Reading `SkyMarks.ceiling` rather than restating a number keeps this true when a deck
    /// offset, `markScale` or a storm amplitude changes.
    static func lift(zoomScale: CGFloat) -> CGFloat {
        SkyMarks.ceiling * zoomScale + clearance
    }

    /// Air between the plane and the tallest cloud, in points. Constant across zooms, so the
    /// gap reads the same whether the sky is 144 points tall or 18.
    static let clearance: CGFloat = 16

    /// The highest the plane may be drawn, so a tall sky cannot push it off the canvas.
    ///
    /// It binds only at the yearly peak fully zoomed in, where the curve itself sits 166.5 from
    /// the top and the sky wants 159.7 of that. Even clamped the plane clears a storm crest by
    /// about 5 points, because the crest is pinned to the same curve.
    static var minimumY: CGFloat { width / PlaneShape.aspect / 2 + 4 }

    /// How far the tilt has travelled from the drawing's own attitude toward the arc's slope.
    ///
    /// 1 zoomed in, 0 at a full day. `skyScale` bottoms out at 0.125 rather than at 0, so it is
    /// renormalised here: used raw it would leave an eighth of the arc's slope mixed into the
    /// high-altitude attitude, which is the one place the drawing is meant to read exactly as
    /// drawn.
    static func tiltProgress(zoomScale: CGFloat) -> CGFloat {
        let floor = CGFloat(DayModel.defaultWindowHours / 24)
        guard floor < 1 else { return 1 }
        return max(0, min(1, (zoomScale - floor) / (1 - floor)))
    }

    /// The rotation to apply to the artwork for a given zoom.
    ///
    /// Level zoomed in, the drawing's own climb at a full day — and deliberately **not** a
    /// function of the curve. Following the arc's local slope was built on 2026-10-21 and taken
    /// out the same afternoon: through sunset that slope runs +6 to +13 degrees, so the plane
    /// nosed DOWN into the horizon line at exactly the moment it crosses it. A mark that reads as
    /// descending into the ground is a worse lie than one that ignores the local gradient, and
    /// the dip below the baseline is where it looked worst.
    ///
    /// The artwork is not level, so this is a difference rather than an assignment: the visible
    /// angle is `drawnAttitude * (1 - progress)`, which lands on 0 zoomed in and on the full
    /// climb at a day.
    static func tilt(zoomScale: CGFloat) -> Angle {
        .degrees(-drawnAttitude.degrees * Double(tiltProgress(zoomScale: zoomScale)))
    }

    /// Fades across the last stretch before the screen edge, so it leaves rather than vanishes.
    ///
    /// With the parallax gone there is no separate exit to find: the plane is on now, so it meets
    /// the edge when now does. 0.82 holds it solid across the middle four-fifths and leaves it
    /// about 39 points to fade over on a 430-point screen.
    static func edgeOpacity(x: CGFloat, centreX: CGFloat) -> Double {
        guard centreX > 0 else { return 1 }
        let away = abs(x - centreX) / centreX
        let holdTo: CGFloat = 0.82
        guard away > holdTo else { return 1 }
        return Double(max(0, 1 - (away - holdTo) / (1 - holdTo)))
    }

    /// Width in points. The height follows `PlaneShape.aspect`, never a second literal.
    ///
    /// 40 because the traced drawing is 2.996:1, which puts the plane 13.4 points tall — close
    /// to the sun dot's 11 and so reading as a mark of the same family rather than as a picture
    /// dropped into the sky. The hand-drawn version this replaced was framed 34 x 20, an aspect
    /// of 1.7 against the source's 3.0, which is most of why it looked wrong.
    static let width: CGFloat = 40

    /// How much the traced ink is thickened, in points.
    ///
    /// The source draws its line at about 4.5 px inside a 255 px-wide drawing, so at 40 points
    /// the ink lands at 0.71 pt — well under the arc's own 1.6 pt stroke, which would leave the
    /// plane reading as a lighter object than the line it flies over. Stroking the filled
    /// outline grows it uniformly without moving a single traced point, so Mason's drawing
    /// survives exactly while its weight stays a number we can set. 0.5 puts the line near
    /// 1.2 pt, between the source's own weight and the arc's.
    static let inkBoost: CGFloat = 0.5

    let mark: Color

    /// Rotation applied to the artwork. `PlaneMark.tilt` is what produces it.
    var tilt: Angle = .zero

    var body: some View {
        PlaneShape()
            .fill(mark)
            .frame(width: Self.width, height: Self.width / PlaneShape.aspect)
            .overlay {
                PlaneShape()
                    .stroke(mark, style: StrokeStyle(lineWidth: Self.inkBoost, lineJoin: .round))
            }
            // After the frame, so it turns the 40 x 13.35 box about its own centre — which is
            // also the point `.position` places, so the tilt never moves the plane off now.
            .rotationEffect(tilt)
            .allowsHitTesting(false)
    }
}
