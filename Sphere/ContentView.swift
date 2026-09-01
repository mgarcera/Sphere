import SwiftUI

struct ContentView: View {
    @State private var model = DayModel()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ArcWindow(day: model.day, focusHour: model.focusHour)
                    .padding(.top, 40)

                Spacer(minLength: 24)

                ClickWheel(
                    onRotate: { model.scrub(byRotations: $0) },
                    onMenu: {
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                            model.returnToNow()
                        }
                    }
                )
                .padding(.bottom, 24)
            }
            .padding(.vertical, 24)
        }
        // Keeps "now" honest across a long session, and carries the dot along
        // with it while the wheel hasn't been touched.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                model.tick()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            // Step 2 placeholder. The brief's title is a task name within 15
            // minutes of the dot, and the planetary hour's call to action
            // otherwise; both arrive in later steps.
            Text(ArcContent.clock(model.focusHour))
                .font(.display())
                .foregroundStyle(Theme.ink)
                .monospacedDigit()

            Text(model.isFocusedOnNow ? Self.dayLine : "\(String(format: "%.1f", model.day.dayLengthHours)) hours of daylight")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private static var dayLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: .now)
    }
}

#Preview {
    ContentView()
}
