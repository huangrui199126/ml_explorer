import SwiftUI

struct CompanyInterviewView: View {
    let papers: [Paper]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var credits = FreeCreditsService.shared
    @StateObject private var svc     = SubscriptionService.shared
    @EnvironmentObject var questionStore: QuestionStore

    @State private var selectedCompany: String? = nil
    @State private var showMockInterview = false
    @State private var showPaywall = false
    @State private var interviewPapers: [Paper] = []
    @State private var interviewTopic: String = ""
    @State private var inferredKeys: Set<String> = []
    @State private var indexLoaded = false

    // MARK: - Derived data (only inferred papers)

    private var inferredPapers: [Paper] {
        guard indexLoaded else { return [] }
        return papers.filter { inferredKeys.contains(InsightService.paperKey(for: $0)) }
    }

    /// Companies that have ≥1 inferred paper, sorted by count desc
    private var companies: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for paper in inferredPapers {
            for company in paper.companies ?? [] {
                counts[company, default: 0] += 1
            }
        }
        return counts.map { (name: $0.key, count: $0.value) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    /// Inferred papers for the selected company, grouped by topic (only non-empty topics)
    private var topicsForCompany: [(topic: String, papers: [Paper])] {
        guard let company = selectedCompany else { return [] }
        let filtered = inferredPapers.filter { $0.companies?.contains(company) == true }
        var grouped: [String: [Paper]] = [:]
        for paper in filtered {
            grouped[paper.topic ?? "Other", default: []].append(paper)
        }
        return grouped
            .map { (topic: $0.key, papers: $0.value) }
            .sorted { $0.papers.count > $1.papers.count }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            if selectedCompany == nil {
                companyList
            } else {
                topicList
            }
        }
        .sheet(isPresented: $showMockInterview) {
            MockInterviewView(
                papers: interviewPapers,
                topic: interviewTopic,
                company: selectedCompany ?? ""
            )
            .environmentObject(questionStore)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .task {
            guard !indexLoaded else { return }
            inferredKeys = await InsightService.shared.fetchIndexedKeys()
            indexLoaded  = true
        }
    }

    // MARK: - Company List

    private var companyList: some View {
        List {
            if !indexLoaded {
                Section {
                    HStack(spacing: 12) {
                        ProgressView().scaleEffect(0.85)
                        Text("Loading available companies…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                }
            } else if companies.isEmpty {
                ContentUnavailableView(
                    "No companies yet",
                    systemImage: "building.2",
                    description: Text("Insights are still being generated. Check back soon.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section("Companies — \(inferredPapers.count) papers ready") {
                    ForEach(companies, id: \.name) { item in
                        Button { withAnimation { selectedCompany = item.name } } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.headline).foregroundStyle(.primary)
                                    Text("\(item.count) paper\(item.count == 1 ? "" : "s") with insights")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundStyle(Color(.tertiaryLabel))
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Company Interview Prep")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
        }
    }

    // MARK: - Topic List

    private var topicList: some View {
        List {
            if topicsForCompany.isEmpty {
                ContentUnavailableView(
                    "No insights yet for \(selectedCompany ?? "")",
                    systemImage: "brain.head.profile",
                    description: Text("Insights are still being generated for these papers.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(topicsForCompany, id: \.topic) { entry in
                    Section {
                        ForEach(entry.papers.prefix(3)) { paper in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(paper.title).font(.subheadline).lineLimit(2)
                                Text(paper.displayAuthors).font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                        }
                        if entry.papers.count > 3 {
                            Text("+ \(entry.papers.count - 3) more")
                                .font(.caption).foregroundStyle(.secondary)
                                .listRowBackground(Color(.secondarySystemGroupedBackground))
                        }
                        startInterviewButton(papers: entry.papers, topic: entry.topic)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    } header: {
                        HStack {
                            Text(entry.topic)
                            Spacer()
                            Text("\(entry.papers.count)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(selectedCompany ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !svc.isPro { freeTierBanner }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { withAnimation { selectedCompany = nil } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Companies")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
        }
    }

    // MARK: - Helpers

    private func startInterviewButton(papers: [Paper], topic: String) -> some View {
        let canStart = credits.canStartInterview(isPro: svc.isPro)
        return Button {
            if canStart {
                credits.consumeInterview()
                interviewPapers   = papers
                interviewTopic    = topic
                showMockInterview = true
            } else {
                showPaywall = true
            }
        } label: {
            HStack {
                Image(systemName: canStart ? "brain.head.profile" : "lock.fill")
                Text(canStart
                     ? "Start Mock Interview  (\(papers.count) papers)"
                     : "Upgrade to Pro — sessions used up")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(canStart ? Color.indigo : Color.gray, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var freeTierBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "brain.head.profile").foregroundStyle(.indigo)
            Text("\(credits.remainingInterviewSessions) session\(credits.remainingInterviewSessions == 1 ? "" : "s") left this month")
                .font(.subheadline)
            Spacer()
            Button("Go Pro") { showPaywall = true }
                .font(.subheadline.bold()).foregroundStyle(.indigo)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
