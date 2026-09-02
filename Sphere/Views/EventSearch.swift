import EventKit
import SwiftUI

/// Finding an event by name.
///
/// The chevrons see forty-five days and the arc draws three, so anything
/// further out had no route at all. This is that route: a year either side,
/// fetched once when the sheet opens so typing filters in memory rather than
/// asking the store on every keystroke.
struct EventSearch: View {
    let events: [EKEvent]
    /// The place's clock, so a result's date matches where it lands on the arc.
    let timeZone: TimeZone
    let onChoose: (EKEvent) -> Void

    @State private var query = ""
    @FocusState private var isFocused: Bool

    private var results: [EKEvent] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return events.filter {
            ($0.title ?? "").localizedStandardContains(trimmed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search events", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .foregroundStyle(Theme.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isFocused)
                .padding(.top, 22)
                .padding(.bottom, 14)

            Rectangle().fill(Theme.hairline).frame(height: 1)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.offset) { index, event in
                        Button { onChoose(event) } label: { row(event) }
                            .buttonStyle(.plain)

                        if index != results.count - 1 {
                            Rectangle().fill(Theme.hairline).frame(height: 1)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
        .onAppear { isFocused = true }
    }

    /// The date is what tells two events of the same name apart, so it carries
    /// as much weight as the title rather than sitting under it.
    private func row(_ event: EKEvent) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(event.calendar.map { Color(cgColor: $0.cgColor) } ?? Theme.taskActive)
                .frame(width: 8, height: 8)
            Text(event.title ?? "Untitled")
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer(minLength: 12)
            Text(dated(event.startDate))
                .font(.footnote)
                .foregroundStyle(Theme.mutedLight)
        }
        .contentShape(.rect)
        .padding(.vertical, 14)
    }

    private func dated(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
