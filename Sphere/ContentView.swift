import SwiftUI

struct ContentView: View {
    private let day = SolarDay(date: .now, coordinate: .chicago)

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text(Self.dayLine)
                    .font(.display())
                    .foregroundStyle(Theme.ink)

                Text(String(format: "%.1f hours of daylight", day.dayLengthHours))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)

                DayArcView(day: day)
                    .padding(.top, 56)

                HStack {
                    Text("12 AM")
                    Spacer()
                    Text("12 PM")
                    Spacer()
                    Text("12 AM")
                }
                .font(.footnote)
                .foregroundStyle(Theme.mutedLighter)
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
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
