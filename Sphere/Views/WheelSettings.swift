import SwiftUI

/// A copy of the wheel, printed with what every position does.
///
/// Its first job is not configuration but documentation. A hold is invisible in
/// the way the arc tap was invisible, and the reason that gesture was taken off
/// the arc was that nothing on screen admitted it existed. This is where the
/// wheel's whole vocabulary is written down, holds included, which is what
/// makes an unprinted gesture acceptable at all.
struct WheelSettings: View {
    @Binding var bottomPrimary: WheelAction
    /// Bumped on every write, so the printed mappings re-read UserDefaults.
    @State private var revision = 0
    @State private var selected: WheelPosition = .bottom
    // TEMPORARY — icon direction study.
    @State private var iconStyle: IconStyle = .words

    private static let diameter: CGFloat = 168
    private static let buttonRatio: CGFloat = 0.383
    private static let labelInsetRatio: CGFloat = 0.108

    private var radius: CGFloat { Self.diameter / 2 }
    private var inset: CGFloat { Self.diameter * Self.labelInsetRatio }
    private var line: Color { Theme.mutedLighter }

    var body: some View {
        VStack(spacing: 16) {
            wheel
            assignment
            studySwitcher
            legend
        }
        .padding(.vertical, 4)
    }

    /// Drawn in the wheel's own line and proportions, at three fifths the size.
    /// Tapping a position selects it rather than performing it: settings is not
    /// a place where the day should move under you.
    private var wheel: some View {
        ZStack {
            Circle().strokeBorder(line, lineWidth: 1.5)

            mark(.centre, x: radius, y: radius)
            mark(.menu, x: radius, y: inset)
            mark(.bottom, x: radius, y: Self.diameter - inset)
            mark(.previous, x: inset, y: radius)
            mark(.next, x: Self.diameter - inset, y: radius)
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .frame(maxWidth: .infinity)
    }

    private func mark(_ position: WheelPosition, x: CGFloat, y: CGFloat) -> some View {
        let isSelected = position == selected
        let size: CGFloat = position == .previous || position == .next ? 17 : 10
        return Text(position.label)
            .font(.system(size: size, weight: size > 14 ? .medium : .semibold))
            .tracking(size > 14 ? 0 : 1.1)
            .foregroundStyle(isSelected ? Theme.ink : line)
            .frame(width: 44, height: 44)
            .background {
                if isSelected {
                    Circle().strokeBorder(Theme.ink.opacity(0.28), lineWidth: 1)
                }
            }
            .contentShape(.rect)
            .onTapGesture { selected = position }
            .position(x: x, y: y)
            .animation(.easeOut(duration: 0.16), value: isSelected)
    }

    // TEMPORARY — icon direction study. Strip with ActionMark.swift.
    private var studySwitcher: some View {
        Picker("Icons", selection: $iconStyle) {
            ForEach(IconStyle.allCases) { style in
                Text(style.title).tag(style)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, 8)
    }

    // TEMPORARY — the whole set at once, which is the only way to judge an
    // icon set rather than one icon.
    private var legend: some View {
        VStack(spacing: 0) {
            ForEach(WheelAction.allCases) { action in
                HStack(spacing: 12) {
                    ActionGlyph(action: action, style: iconStyle)
                    Text(action.title)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(.vertical, 9)

                if action != WheelAction.allCases.last {
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                }
            }
        }
    }

    /// What the selected position does, both ways round.
    @ViewBuilder
    private var assignment: some View {
        let _ = revision
        VStack(spacing: 0) {
            row("Tap", value: selected.tapTitle,
                action: selected == .bottom ? bottomPrimary : .none,
                picker: selected == .bottom ? bottomPicker : nil)
            Rectangle().fill(Theme.hairline).frame(height: 1)
            row("Hold",
                value: WheelMapping.hold(for: selected).title,
                action: WheelMapping.hold(for: selected),
                picker: selected.holdIsAssignable ? holdPicker : nil)
        }
    }

    /// Only the assignable half carries a control. Where a gesture is fixed the
    /// row still prints what it does, since knowing is the point.
    @ViewBuilder
    private func row<Picker: View>(_ gesture: String, value: String, action: WheelAction, picker: Picker?) -> some View {
        HStack {
            Text(gesture)
                .font(.system(size: 11, weight: .medium))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.mutedLight)
            Spacer()
            if let picker {
                picker
            } else {
                HStack(spacing: 8) {
                    ActionGlyph(action: action, style: iconStyle, color: Theme.mutedLight)
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(Theme.mutedLight)
                }
            }
        }
        .padding(.vertical, 12)
    }

    /// The bottom's two gestures share one pair, so setting the tap sets the
    /// hold to the other. Neither can be lost.
    private var bottomPicker: some View {
        Menu {
            ForEach([WheelAction.now, .calendar]) { action in
                Button(action.title) { bottomPrimary = action; revision += 1 }
            }
        } label: {
            Text(bottomPrimary.title)
                .font(.subheadline)
                .foregroundStyle(Theme.controlAccent)
        }
    }

    private var holdPicker: some View {
        Menu {
            ForEach(selected.assignableActions) { action in
                Button(action.title) {
                    WheelMapping.setHold(action, for: selected)
                    revision += 1
                }
            }
        } label: {
            Text(WheelMapping.hold(for: selected).title)
                .font(.subheadline)
                .foregroundStyle(Theme.controlAccent)
        }
    }
}
