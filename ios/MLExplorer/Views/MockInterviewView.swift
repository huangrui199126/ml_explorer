import SwiftUI

// MARK: - Card model

private struct FlashCard: Identifiable {
    let id = UUID()
    let paperId: String
    let paperTitle: String
    let question: String
    let answer: String
}

// MARK: - View

struct MockInterviewView: View {
    let papers: [Paper]
    let topic: String
    let company: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var questionStore: QuestionStore
    @State private var cards: [FlashCard] = []
    @State private var currentIndex = 0
    @State private var isLoading = true
    @State private var isRevealed = false
    @State private var gotItCount = 0
    @State private var studyAgainCount = 0
    @State private var isFinished = false
    @State private var dragOffset: CGFloat = 0
    @State private var dragRotation: Double = 0

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if isFinished || cards.isEmpty {
                    resultsView
                } else {
                    cardSessionView
                }
            }
            .navigationTitle("\(company)  ·  \(topic)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Exit") { dismiss() }
                }
            }
        }
        .task { await loadCards() }
    }

    // MARK: - Card Session

    private var cardSessionView: some View {
        VStack(spacing: 0) {
            progressHeader
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Spacer()

            ZStack {
                // Peek at next card
                if currentIndex + 1 < cards.count {
                    cardShape(cards[currentIndex + 1], revealed: false)
                        .scaleEffect(0.94)
                        .offset(y: 12)
                        .opacity(0.5)
                }
                // Current card
                cardShape(cards[currentIndex], revealed: isRevealed)
                    .offset(x: dragOffset)
                    .rotationEffect(.degrees(dragRotation))
                    .gesture(dragGesture)
            }
            .padding(.horizontal, 20)

            Spacer()

            if isRevealed {
                actionButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                revealButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.3), value: isRevealed)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Flash Card Shape

    private func cardShape(_ card: FlashCard, revealed: Bool) -> some View {
        let isSaved = questionStore.isSaved(question: card.question, paperId: card.paperId)
        return VStack(alignment: .leading, spacing: 14) {
            // Paper badge + bookmark
            HStack(alignment: .top) {
                Text(card.paperTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
                Spacer()
                Button {
                    questionStore.toggle(
                        question: card.question,
                        answer: card.answer,
                        paperId: card.paperId,
                        paperTitle: card.paperTitle
                    )
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16))
                        .foregroundStyle(isSaved ? Color.indigo : Color.secondary)
                }
                .buttonStyle(.plain)
            }

            // Question
            Text(card.question)
                .font(.title3)
                .fontWeight(.semibold)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if revealed {
                Divider()
                ScrollView {
                    Text(card.answer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.07), radius: 14, y: 5)
    }

    // MARK: - Drag Gesture (swipe after reveal)

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard isRevealed else { return }
                dragOffset   = value.translation.width
                dragRotation = value.translation.width / 22
            }
            .onEnded { value in
                guard isRevealed else { return }
                if abs(value.translation.width) > 110 {
                    advance(gotIt: value.translation.width > 0)
                } else {
                    withAnimation(.spring()) {
                        dragOffset   = 0
                        dragRotation = 0
                    }
                }
            }
    }

    // MARK: - Buttons

    private var revealButton: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) { isRevealed = true }
        } label: {
            Text("Reveal Answer")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.indigo, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 14) {
            actionButton(
                title: "Study Again",
                icon: "arrow.counterclockwise",
                color: .orange
            ) { advance(gotIt: false) }

            actionButton(
                title: "Got It",
                icon: "checkmark",
                color: .green
            ) { advance(gotIt: true) }
        }
    }

    private func actionButton(
        title: String, icon: String, color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(color)
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(currentIndex + 1) / \(cards.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 14) {
                    Label("\(gotItCount)", systemImage: "checkmark")
                        .font(.caption).foregroundStyle(.green)
                    Label("\(studyAgainCount)", systemImage: "arrow.counterclockwise")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            ProgressView(value: Double(currentIndex), total: Double(max(cards.count, 1)))
                .tint(.indigo)
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: cards.isEmpty ? "exclamationmark.triangle" : "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(cards.isEmpty ? .orange : .indigo)

            if cards.isEmpty {
                Text("No questions available yet")
                    .font(.title3).fontWeight(.semibold)
                Text("Insights are still being generated for these papers. Try again in a few minutes.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            } else {
                Text("Session Complete!")
                    .font(.title2).fontWeight(.bold)

                HStack(spacing: 40) {
                    scoreStat(value: gotItCount,      label: "Got It",      color: .green)
                    scoreStat(value: studyAgainCount, label: "Study Again", color: .orange)
                }

                let pct = Int(Double(gotItCount) / Double(max(cards.count, 1)) * 100)
                Text("\(pct)% confidence rate")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.indigo)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func scoreStat(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.4)
            Text("Loading questions…")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("Fetching insights for up to \(min(papers.count, 10)) papers")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Data Loading

    private func loadCards() async {
        var loaded: [FlashCard] = []
        for paper in papers.prefix(10) {
            if let shared = await InsightService.shared.fetchSharedInsight(for: paper),
               let deep = shared.deep {
                let key = await InsightService.shared.paperKey(for: paper)
                for (q, a) in zip(deep.interviewQuestions, deep.interviewAnswers) {
                    loaded.append(FlashCard(
                        paperId: key,
                        paperTitle: paper.title,
                        question: q,
                        answer: a
                    ))
                }
            }
        }
        loaded.shuffle()
        await MainActor.run {
            cards     = loaded
            isLoading = false
        }
    }

    // MARK: - Advance

    private func advance(gotIt: Bool) {
        let target: CGFloat = gotIt ? 500 : -500
        withAnimation(.spring(duration: 0.35)) {
            dragOffset   = target
            dragRotation = target / 15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if gotIt { gotItCount += 1 } else { studyAgainCount += 1 }
            currentIndex += 1
            if currentIndex >= cards.count {
                isFinished = true
            } else {
                dragOffset   = 0
                dragRotation = 0
                isRevealed   = false
            }
        }
    }
}
