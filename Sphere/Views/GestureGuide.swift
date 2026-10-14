import SwiftUI

/// Every gesture the arc has, one per page, on the same ground as the three choice sheets the
/// tap and this sheet's own openers raise (Mason, 2026-10-10): `TimeChoiceSheet` and
/// `EventChoiceSheet` from a tap, and `CornerChoiceSheet` from either the corner's question mark
/// or a long press. It said "three" and "the header button" until 2026-10-13, when the header
/// button turned out to open the editor and never a choice sheet; "four" until 2026-10-14, when
/// the hold stopped having a sheet of its own and joined the corner's.
///
/// It was an overlay on the arc that ran all six in sequence and then left. Two things were
/// wrong with that: a reader who missed one could not go back to it, and a layer drawn over the
/// thing it is describing has to be dim enough not to hide it, which is the opposite of what a
/// first explanation wants. In a sheet it can be plain ink on the app's own ground, and the
/// reader sets the pace.
///
/// Reached through the "?" in the corner, which since 2026-10-13 asks Guide or Menu first, and
/// twice without being asked for: when the onboarding hands over, and once for anyone who was
/// already past onboarding when the guide arrived. Both of those open it directly, because an
/// explanation that comes to you cannot put a question in front of itself.
struct GestureGuide: View {
    /// Room for the hand, a caption that wraps to two lines, and the dots, with the same 18pt of
    /// air over the top that the two-card sheets have.
    static let height: CGFloat = 300

    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(GestureLesson.all.enumerated()), id: \.element.id) { index, lesson in
                    VStack(spacing: 28) {
                        GestureDemo(lesson: lesson, mark: Theme.ink, isActive: page == index)
                        Text(lesson.word)
                            .font(.footnote)
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 18)
                    .tag(index)
                }
            }
            // The system's own dots are a fixed grey that belongs to neither pole, and this app
            // draws in ink or paper and nothing between.
            .tabViewStyle(.page(indexDisplayMode: .never))

            dots
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(Array(GestureLesson.all.enumerated()), id: \.element.id) { index, _ in
                Circle()
                    .fill(Theme.ink.opacity(index == page ? 1 : 0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .animation(.easeOut(duration: 0.2), value: page)
        // Circles publish nothing, and the pager's own indicator reported 0% on every page
        // including the last, so without this VoiceOver gets no position at all while paging
        // (measured 2026-10-10). One element with a spoken position, rather than six shapes.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(GestureLesson.all.count)")
    }
}
