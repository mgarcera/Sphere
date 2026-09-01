import SwiftUI

/// Shown before the system prompt. iOS asks once and a cold denial is close to
/// permanent, so the reason goes first.
struct CalendarPriming: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Your day, on the sun's arc")
                .font(.display(26))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Text("""
                 Sphere draws today as the sun's own elevation curve and lays \
                 your calendar along it. To do that it needs to read your \
                 events. Nothing leaves your phone.
                 """)
                .font(.callout)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 14)
                .padding(.horizontal, 8)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.ink, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
