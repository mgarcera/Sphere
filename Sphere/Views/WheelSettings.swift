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
    @AppStorage(Haptics.key) private var hapticsEnabled = true
    @State private var isConfirmingReset = false

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
            switches
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

    /// Haptics belong to the wheel, so the switch lives with it rather than in
    /// a section of its own.
    private var switches: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.hairline).frame(height: 1)

            Toggle(isOn: $hapticsEnabled) {
                Text("Haptics")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
            }
            .tint(Theme.controlAccent)
            .padding(.vertical, 8)

            Rectangle().fill(Theme.hairline).frame(height: 1)

            Button { isConfirmingReset = true } label: {
                HStack {
                    Text("Reset to default")
                        .font(.subheadline)
                        .foregroundStyle(WheelMapping.isDefault ? Theme.mutedLight : Theme.controlAccent)
                    Spacer()
                }
                .contentShape(.rect)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .disabled(WheelMapping.isDefault)
        }
        .padding(.top, 4)
        // A confirmation, because a reset undoes every position at once and
        // there is nothing on screen to read back what was there before.
        .confirmationDialog("Reset the wheel?",
                            isPresented: $isConfirmingReset,
                            titleVisibility: .visible) {
            Button("Reset to default", role: .destructive) {
                WheelMapping.resetAll()
                bottomPrimary = WheelMapping.bottomPrimary
                revision += 1
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every tap and hold goes back to how it shipped.")
        }
    }

    /// What the selected position does, both ways round and side by side.
    ///
    /// Two columns rather than two stacks: the two slots are alternatives to
    /// each other, and reading them down the page made the second look like a
    /// consequence of the first. Aligned to the top so the two headers sit on
    /// one line however unevenly the lists below them run.
    @ViewBuilder
    private var assignment: some View {
        let _ = revision
        HStack(alignment: .top, spacing: 18) {
            column(.tap,
                   mark: selected.tapMark,
                   value: selected.tapTitle,
                   current: selected == .bottom ? bottomPrimary : nil,
                   options: selected == .bottom ? [.now, .calendar] : [])

            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1)

            column(.hold,
                   mark: WheelMapping.hold(for: selected).mark,
                   value: WheelMapping.hold(for: selected).title,
                   current: WheelMapping.hold(for: selected),
                   options: selected.assignableActions)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A fixed slot prints what it does. An assignable one lists its choices
    /// instead: nothing to open, and the one in force reads at full strength
    /// while the rest sit back. The brightness is the state, so there is no
    /// tick or radio to add.
    @ViewBuilder
    private func column(_ gesture: WheelGesture, mark: Mark, value: String,
                        current: WheelAction?, options: [WheelAction]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Named for what they are to the user, not for the gesture that
            // reaches them: one is the thing the button is for, the other is
            // the thing it also does.
            Text(gesture == .tap ? "Primary" : "Secondary")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.mutedLight)
                .padding(.bottom, 10)

            if options.count > 1 {
                ForEach(options) { option in
                    slot(mark: option.mark, title: option.title, color: Theme.ink)
                        .opacity(option == current ? 1 : 0.32)
                        .contentShape(.rect)
                        .onTapGesture { choose(option, for: gesture) }
                }
            } else {
                slot(mark: mark, title: value, color: Theme.mutedLight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.16), value: current)
    }

    /// One line of the column. The mark keeps its own width so the titles line
    /// up under each other even where one of them wraps.
    private func slot(mark: Mark, title: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ActionMark(mark: mark, size: 18, color: color)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
    }

    private func choose(_ action: WheelAction, for gesture: WheelGesture) {
        if gesture == .tap {
            bottomPrimary = action
        } else {
            WheelMapping.setHold(action, for: selected)
        }
        revision += 1
    }

}
