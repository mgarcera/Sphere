import SwiftUI

struct ContentView: View {
    @State private var model = DayModel()
    @State private var isAdding = false
    @State private var draft = ""
    @FocusState private var draftFocused: Bool

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ArcWindow(
                    day: model.day,
                    focusHour: model.focusHour,
                    tasks: model.tasks,
                    activeTaskID: model.activeTask?.id
                )
                .padding(.top, 40)

                Spacer(minLength: 16)

                if isAdding { addField }

                ClickWheel(
                    onRotate: { model.scrub(byRotations: $0) },
                    onMenu: {
                        closeAddField()
                        springTo { model.returnToNow() }
                    },
                    onCentre: toggleAddField,
                    onPrevious: { springTo { model.jumpToPreviousTask() } },
                    onNext: { springTo { model.jumpToNextTask() } }
                )
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .padding(.vertical, 24)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                model.tick()
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 6) {
            // Within fifteen minutes of a task the title is that task's name.
            // Outside it, the planetary hour's call to action takes over — that
            // arrives in step 4, so the clock stands in for now.
            Text(model.activeTask?.label ?? ArcContent.clock(model.focusHour))
                .font(.display())
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.18), value: model.activeTask?.id)

            Text(model.activeTask == nil
                 ? (model.isFocusedOnNow ? Self.dayLine : "\(String(format: "%.1f", model.day.dayLengthHours)) hours of daylight")
                 : ArcContent.clock(model.activeTask?.hour ?? model.focusHour))
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    /// Creates a task at whatever hour the wheel is currently on.
    private var addField: some View {
        VStack(spacing: 6) {
            TextField("Add something", text: $draft)
                .font(.display(17))
                .foregroundStyle(Theme.ink)
                .focused($draftFocused)
                .submitLabel(.done)
                .onSubmit(commitDraft)
                .multilineTextAlignment(.center)

            Rectangle()
                .fill(Theme.hairlineSoft)
                .frame(height: 1)

            Text("at \(ArcContent.clock(model.focusHour))")
                .font(.footnote)
                .foregroundStyle(Theme.mutedLight)
                .monospacedDigit()
        }
        .padding(.horizontal, 48)
        .transition(.opacity)
    }

    // MARK: - Actions

    private func toggleAddField() {
        if isAdding {
            commitDraft()
        } else {
            withAnimation(.easeOut(duration: 0.2)) { isAdding = true }
            draftFocused = true
        }
    }

    private func commitDraft() {
        model.addTask(label: draft)
        closeAddField()
    }

    private func closeAddField() {
        guard isAdding else { return }
        draft = ""
        draftFocused = false
        withAnimation(.easeOut(duration: 0.2)) { isAdding = false }
    }

    private func springTo(_ change: () -> Void) {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86), change)
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
