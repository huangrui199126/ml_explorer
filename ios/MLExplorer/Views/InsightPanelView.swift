import SwiftUI

// MARK: - Pro gate overlay

struct ProGateOverlay: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let bullets: [String]

    @State private var showPaywall = false
    @ObservedObject private var credits = FreeCreditsService.shared

    init(icon: String, color: Color, title: String, subtitle: String,
         bullets: [String] = []) {
        self.icon     = icon
        self.color    = color
        self.title    = title
        self.subtitle = subtitle
        self.bullets  = bullets
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "7B2FF7").opacity(0.18),
                                         Color(hex: "2196F3").opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing)
                        )
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "7B2FF7"), Color(hex: "2196F3")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing)
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("PRO")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "7B2FF7"), Color(hex: "2196F3")],
                                    startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 14)

            // Feature bullets
            if !bullets.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(bullets, id: \.self) { bullet in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "7B2FF7"))
                            Text(bullet)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 14)
            }

            // CTA
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Unlock with Pro")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "7B2FF7"), Color(hex: "2196F3")],
                        startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            }
            .buttonStyle(.plain)

            // Price hint
            Text("From $2.99/mo · Cancel anytime")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "7B2FF7").opacity(0.3),
                                         Color(hex: "2196F3").opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
        )
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}

// MARK: - Quick Insight Card

struct QuickInsightCard: View {
    @ObservedObject var vm: InsightViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Quick Insight", icon: "bolt.fill", color: .orange)
                .padding(.bottom, 12)

            if vm.isGeneratingFast {
                generatingRow("Generating quick insight…")
            } else if let insight = vm.fastInsight {
                insightContent(insight)
            } else if let error = vm.fastError {
                errorRow(error) { Task { await vm.retryFast() } }
            } else {
                noAPIKeyHint
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func insightContent(_ i: FastInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            insightRow(icon: "text.alignleft", label: "Summary", text: i.summary)
            insightRow(icon: "lightbulb.fill", label: "Key Idea", text: i.keyIdea)
            insightRow(icon: "chart.line.uptrend.xyaxis", label: "Why It Matters", text: i.whyItMatters)

            if !i.possibleUseCases.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Use Cases", systemImage: "gearshape.2")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    ForEach(i.possibleUseCases, id: \.self) { uc in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").foregroundStyle(.orange)
                            Text(uc).font(.subheadline)
                        }
                    }
                }
            }
        }
    }

    private var noAPIKeyHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.orange.opacity(0.7))
                Text("AI insights not yet available for this paper.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Open the SORT-Gen (Taobao) paper to see a live demo, or add an Anthropic API key in ⚙️ Settings to generate insights for any paper.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Deep Insight Card

struct DeepInsightCard: View {
    @ObservedObject var vm: InsightViewModel
    @ObservedObject private var svc     = SubscriptionService.shared
    @ObservedObject private var credits = FreeCreditsService.shared
    @State private var expanded = false
    // creditConsumed tracks whether THIS view instance already spent a credit
    @State private var creditConsumed = false

    // True only if the user actually has/had a credit for this view session
    private var canView: Bool {
        svc.isPro || creditConsumed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionHeader("Advanced Analysis", icon: "brain.head.profile", color: .purple)
                if !svc.isPro {
                    Spacer()
                    creditBadge
                }
            }
            .padding(.bottom, 12)

            if canView {
                // Full content
                if vm.isGeneratingDeep {
                    generatingRow("Running deep analysis…")
                } else if let error = vm.deepError {
                    errorRow(error) { Task { await vm.retryDeep() } }
                } else if let insight = vm.deepInsight {
                    deepContent(insight)
                } else if vm.fastInsight != nil {
                    pendingRow
                }
            } else if let insight = vm.deepInsight {
                // Teaser: show first ~100 chars blurred, then gate
                teaserContent(insight)
            } else {
                ProGateOverlay(
                    icon: "brain.head.profile",
                    color: .purple,
                    title: "Advanced Analysis",
                    subtitle: "See how the method actually works",
                    bullets: [
                        "Step-by-step method breakdown",
                        "What's genuinely new vs prior work",
                        "Key design choices & why they work",
                        "Limitations & failure cases"
                    ]
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear { consumeCreditIfNeeded() }
        .onChange(of: vm.deepInsight != nil) { _, hasInsight in
            if hasInsight { consumeCreditIfNeeded() }
        }
    }

    private func consumeCreditIfNeeded() {
        guard !svc.isPro, !creditConsumed, vm.deepInsight != nil else { return }
        // Only consume if credits are available
        if credits.remainingCredits > 0 {
            credits.consume()
            creditConsumed = true
        }
        // If 0 credits, creditConsumed stays false → teaser shown
    }

    private var creditBadge: some View {
        Text(credits.remainingCredits == 0 ? "No previews left" : "\(credits.remainingCredits) free left")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(credits.remainingCredits == 0 ? .red : .purple)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                (credits.remainingCredits == 0 ? Color.red : Color.purple).opacity(0.12),
                in: Capsule()
            )
    }

    // MARK: - Teaser (short preview for 0-credit users)

    private func teaserContent(_ d: DeepInsight) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Show first ~100 chars of the analysis, then a hard cutoff
            VStack(alignment: .leading, spacing: 4) {
                Label("How It Works", systemImage: "gearshape.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                let preview = String(d.methodBreakdown.prefix(100))
                Text(preview + "…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)

            // Unlock gate
            ProGateOverlay(
                icon: "brain.head.profile",
                color: .purple,
                title: "Advanced Analysis",
                subtitle: "You've used all 3 free previews this month",
                bullets: [
                    "Step-by-step method breakdown",
                    "What's genuinely new vs prior work",
                    "Key design choices & why they work",
                    "Limitations & failure cases"
                ]
            )
        }
    }

    private func deepContent(_ d: DeepInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            insightRow(icon: "gearshape.fill", label: "How It Works", text: d.methodBreakdown)
            insightRow(icon: "sparkles", label: "Key Innovation", text: d.keyInnovation)
            insightRow(icon: "cpu", label: "Technical Insight", text: d.technicalInsight)
            insightRow(icon: "exclamationmark.triangle", label: "Limitations", text: d.limitations)
        }
    }

    private var pendingRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.questionmark")
                .foregroundStyle(.purple)
            Text("Deep analysis queued — opens when you read the paper.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Interview Prep Card

struct InterviewPrepCard: View {
    let deep: DeepInsight
    let paper: Paper
    @EnvironmentObject var questionStore: QuestionStore
    @ObservedObject private var svc = SubscriptionService.shared
    @State private var openIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Interview Prep", icon: "person.fill.questionmark", color: .teal)
                .padding(.bottom, 12)

            if !svc.isPro {
                ProGateOverlay(
                    icon: "person.fill.questionmark",
                    color: .teal,
                    title: "Interview Prep",
                    subtitle: "Practice with AI-generated Q&As for this paper",
                    bullets: [
                        "5 interview questions per paper",
                        "Detailed model answers",
                        "Track New → Learning → Mastered",
                        "Review all saved questions in one place"
                    ]
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(zip(deep.interviewQuestions, deep.interviewAnswers).enumerated()),
                            id: \.offset) { idx, pair in
                        let (q, a) = pair
                        qaRow(idx: idx, question: q, answer: a)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func qaRow(idx: Int, question: String, answer: String) -> some View {
        let saved = questionStore.isSaved(question: question, paperId: paper.id)
        let savedQ = questionStore.questions.first { $0.question == question && $0.paperId == paper.id }

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                // Expand/collapse button
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        openIndex = openIndex == idx ? nil : idx
                    }
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Text("Q\(idx + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.teal, in: Circle())
                        Text(question)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: openIndex == idx ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                // Save / status button
                Button {
                    questionStore.toggle(question: question, answer: answer,
                                         paperId: paper.id, paperTitle: paper.title)
                } label: {
                    if let sq = savedQ {
                        Image(systemName: sq.status.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(sq.status.color)
                    } else {
                        Image(systemName: "bookmark")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(.vertical, 8)

            if openIndex == idx {
                VStack(alignment: .leading, spacing: 8) {
                    Text(answer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 32)

                    // Status control (only if saved)
                    if let sq = savedQ {
                        HStack(spacing: 8) {
                            Spacer()
                            ForEach(QuestionStatus.allCases, id: \.self) { status in
                                Button {
                                    questionStore.setStatus(sq.id, status: status)
                                } label: {
                                    Label(status.rawValue, systemImage: status.icon)
                                        .font(.caption)
                                        .fontWeight(sq.status == status ? .semibold : .regular)
                                        .foregroundStyle(sq.status == status ? status.color : .secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            sq.status == status ? status.color.opacity(0.12) : Color.clear,
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.leading, 32)
                        .padding(.bottom, 4)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .padding(.bottom, 4)
            }

            if idx < (deep.interviewQuestions.count - 1) {
                Divider().padding(.leading, 32)
            }
        }
    }
}

// MARK: - Shared helpers

func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
    HStack(spacing: 6) {
        Image(systemName: icon)
            .foregroundStyle(color)
        Text(title)
            .font(.headline)
        Spacer()
    }
}

func insightRow(icon: String, label: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Label(label, systemImage: icon)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
        Text(text)
            .font(.subheadline)
    }
}

func generatingRow(_ label: String) -> some View {
    HStack(spacing: 10) {
        ProgressView().scaleEffect(0.8)
        Text(label)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

func errorRow(_ message: String, retry: @escaping () -> Void) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Button("Retry", action: retry)
            .font(.caption)
            .buttonStyle(.bordered)
    }
}
