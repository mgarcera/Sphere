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
    /// Which row is expanded. A system menu renders text and images only, so
    /// the marks could never appear in one; choosing happens inline instead.
    @State private var choosing: WheelGesture?
    @AppStorage(WheelMapping.iconsKey) private var wheelShowsIcons = false
    @AppStorage(Haptics.key) private var hapticsEnabled = true

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

    /// Both switches belong to the wheel, so they live with it rather than in
    /// a section of their own.
    private var switches: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.hairline).frame(height: 1)

            Toggle(isOn: $wheelShowsIcons) {
                Text("Icons instead of words")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
            }
            .tint(Theme.controlAccent)
            .padding(.vertical, 8)

            Toggle(isOn: $hapticsEnabled) {
                Text("Haptics")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
            }
            .tint(Theme.controlAccent)
            .padding(.vertical, 8)
        }
        .padding(.top, 4)
    }

    /// What the selected position does, both ways round.
    @ViewBuilder
    private var assignment: some View {
        let _ = revision
        VStack(spacing: 0) {
            row(.tap,
                mark: selected.tapMark,
                value: selected.tapTitle,
                options: selected == .bottom ? [.now, .calendar] : [])
            Rectangle().fill(Theme.hairline).frame(height: 1)
            row(.hold,
                mark: WheelMapping.hold(for: selected).mark,
                value: WheelMapping.hold(for: selected).title,
                options: selected.assignableActions)
        }
        .animation(.easeOut(duration: 0.18), value: choosing)
        .onChange(of: selected) { _, _ in choosing = nil }
    }

    /// A fixed gesture still prints what it does, since knowing is the point.
    /// An assignable one opens its choices underneath rather than over the top,
    /// so the mark you are picking sits next to the one you have.
    @ViewBuilder
    private func row(_ gesture: WheelGesture, mark: Mark, value: String, options: [WheelAction]) -> some View {
        let isOpen = choosing == gesture

        VStack(spacing: 0) {
            HStack {
                Text(gesture == .tap ? "Tap" : "Hold")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.mutedLight)
                Spacer()
                ActionMark(mark: mark, size: 18,
                           color: options.isEmpty ? Theme.mutedLight : Theme.controlAccent)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(options.isEmpty ? Theme.mutedLight : Theme.controlAccent)
            }
            .contentShape(.rect)
            .padding(.vertical, 12)
            .onTapGesture {
                guard !options.isEmpty else { return }
                choosing = isOpen ? nil : gesture
            }

            if isOpen {
                VStack(spacing: 0) {
                    ForEach(options) { option in
                        HStack(spacing: 10) {
                            ActionMark(mark: option.mark, size: 18, color: Theme.ink)
                            Text(option.title)
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                            Spacer()
                        }
                        .contentShape(.rect)
                        .padding(.vertical, 10)
                        .onTapGesture { choose(option, for: gesture) }
                    }
                }
                .padding(.leading, 8)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func choose(_ action: WheelAction, for gesture: WheelGesture) {
        if gesture == .tap {
            bottomPrimary = action
        } else {
            WheelMapping.setHold(action, for: selected)
        }
        revision += 1
        choosing = nil
    }

}
