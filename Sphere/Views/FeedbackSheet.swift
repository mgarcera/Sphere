import SwiftUI
import SmidgecraftKit

/// A calm feedback form: optional sentiment + a message (+ an optional email for
/// a reply). Posted to Formspree via `FeedbackService`, which emails it to Mason — no account,
/// no backend, no keys.
///
/// On `SmidgecraftKit` since 2026-10-04: the submission, the payload and every word come from the
/// package, and this file is only the drawing. Sphere was the source the package's service was
/// carried from, so the payload it sends is unchanged.
///
/// What deliberately did NOT converge is the layout. Sphere draws its fields as hairline
/// rectangles because nothing else in this app is a card; Weeklite uses a stock `Form` because
/// that IS Weeklite's register.
struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var email = ""
    @State private var sentiment: String?
    @State private var isSending = false
    @State private var outcome: Outcome?
    @FocusState private var messageFocused: Bool

    private enum Outcome { case sent, failed }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(FeedbackCopy.prompt)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.mutedLight)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 14) {
                        ForEach(FeedbackCopy.sentiments, id: \.self) { emoji in
                            Button {
                                sentiment = (sentiment == emoji) ? nil : emoji
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 28))
                                    .opacity(sentiment == nil || sentiment == emoji ? 1 : 0.3)
                                    .scaleEffect(sentiment == emoji ? 1.15 : 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .animation(.snappy(duration: 0.2), value: sentiment)

                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text(FeedbackCopy.messagePlaceholder)
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.mutedLighter)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $message)
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.ink)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 140)
                            .focused($messageFocused)
                    }
                    .padding(12)
                    .background(field)

                    TextField(FeedbackCopy.emailPlaceholder, text: $email)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.ink)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(field)

                    Button {
                        Task { await send() }
                    } label: {
                        Text(isSending ? FeedbackCopy.sending : FeedbackCopy.send)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Theme.ink, in: Capsule())
                            .opacity(canSend ? 1 : 0.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend || isSending)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(FeedbackCopy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.background)
        .onAppear { messageFocused = true }
        .alert(FeedbackCopy.sentTitle, isPresented: alertBinding(.sent)) {
            Button("OK") { dismiss() }
        } message: {
            Text(FeedbackCopy.sentBody)
        }
        .alert(FeedbackCopy.failedTitle, isPresented: alertBinding(.failed)) {
            Button("OK") {}
        } message: {
            Text(FeedbackCopy.failedBody(replyAddress: SphereFeedback.form.replyAddress))
        }
    }

    /// A hairline rectangle, the way every other edge in this app is drawn.
    private var field: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Theme.hairline, lineWidth: 1)
    }

    private var canSend: Bool { FeedbackService.canSend(message) }

    private func alertBinding(_ target: Outcome) -> Binding<Bool> {
        Binding(get: { outcome == target }, set: { if !$0 { outcome = nil } })
    }

    private func send() async {
        isSending = true
        do {
            try await FeedbackService.submit(SphereFeedback.form, message: message, email: email, sentiment: sentiment)
            outcome = .sent
        } catch {
            outcome = .failed
        }
        isSending = false
    }
}

/// Sphere's feedback form, which is now only its three facts. The submission, the payload and the
/// words all come from `SmidgecraftKit` (2026-10-04).
///
/// Each app has its own Formspree form; manage them at formspree.io. The form id is the only
/// thing here that cannot be derived, which is why these three lines did not move into the
/// package with everything else.
enum SphereFeedback {
    static let form = FeedbackForm(formID: "xnpqzgeb",
                                   appName: "Sphere",
                                   replyAddress: SphereLinks.contactEmail)
}
