import SwiftUI

/// One card in a two-card sheet: a mark, a word under it, and nothing else.
///
/// Drawn in the wheel's line and weight, since the wheel's own centre button is where this
/// treatment came from. Presses dim rather than scale, for the same reason they did there.
///
/// Shared by both sheets that use it (2026-10-10). A heading and a caption under each card were
/// tried and cut: a fork with two one-word answers reads as a form the moment anything explains
/// it. Keeping the card here rather than inside one sheet means the second sheet inherits the
/// treatment instead of copying it.
struct ChoiceCard: View {
    let mark: Mark
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 18) {
                ActionMark(mark: mark, size: 96, color: Theme.ink, stroke: 2.0)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // No frame at all. The mark and its word are the button; a border around them was
            // drawing the container rather than the choice.
            .contentShape(.rect)
        }
        .buttonStyle(DimOnPress())
    }
}

/// The two cards in a sheet whose own ground is painted, since a sheet's default is a
/// translucent material and nothing else here is translucent.
struct ChoiceSheet<Content: View>: View {
    static var height: CGFloat { 200 }
    @ViewBuilder let cards: () -> Content

    var body: some View {
        HStack(spacing: 14) {
            cards()
        }
        .frame(height: 150)
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }
}

/// The same cards, centred, for a screen whose scarce axis is height.
///
/// A bottom sheet spends height, and landscape has 402 points of it against 874 in portrait — so
/// the detent that reads as a quarter of the screen there covers half of it here, and the day
/// picker's 420 was taller than the screen outright. Three cards in a row is a horizontal
/// arrangement and landscape is a horizontal shape; this stops fighting that (Mason, 2026-10-10).
struct ChoicePanel<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder let cards: () -> Content

    var body: some View {
        ZStack {
            // Tapping away closes it, which is the affordance a sheet got for free from its
            // grabber and its drag. Paper rather than black: the sheets paint their own ground
            // and a black scrim would be the only dark thing in a light app.
            Theme.background.opacity(0.82)
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture(perform: onDismiss)

            HStack(spacing: 14) {
                cards()
            }
            .frame(height: 132)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(Theme.background)
            .clipShape(.rect(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.hairline, lineWidth: 1))
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }
}

struct DimOnPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.45 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
