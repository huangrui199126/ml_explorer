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
    /// Papers that have a pre-generated insight — loaded once from the index
    @State private var inferredKeys: Set<String> = []
    @State private var indexLoaded = false

    /// Only papers that are already inferred (in the index)
    private var inferredPapers: [Paper] {
        guard indexLoaded else { return [] }
        return papers.filter { inferredKeys.contains(InsightService.shared.paperKey(for: $0)) }
    }

    private var papersForCompany: [String: [Paper]] {
        guard let company = selectedCompany else { return [:] }
        let filtered = inferredPapers.filter { $0.companies?.contains(company) == true }
        var grouped: [String: [Paper]] = [:]
        for paper in filtered {
            grouped[paper.topic ?? "Other", default: []].append(paper)
        }
        return grouped
    }

    private var companies: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for paper in inferredPapers {
            for company in paper.companies ?? [] {
                counts[company, default: 0] += 1
            }
        }
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

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
            Section {
                Text("Pick a company to study their research papers and practice interview questions by topic.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            if !indexLoaded {
                Section {
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text("Loading available papers…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                }
            }
            Section("Companies (\(inferredPapers.count) papers with insights)") {
                ForEach(companies, id: \.name) { item in
                    Button {
                        withAnimation { selectedCompany = item.name }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(item.count) paper\(item.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Company Interview Prep")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: - Topic List

    private var topicList: some View {
        let sortedTopics = papersForCompany.keys.sorted {
            (papersForCompany[$0]?.count ?? 0) > (papersForCompany[$1]?.count ?? 0)
        }
        return List {
            Section {
                Text("Papers from \(selectedCompany ?? "") grouped by research area. Start a mock interview to practice Q&A from those papers.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(sortedTopics, id: \.self) { topic in
                let topicPapers = papersForCompany[topic] ?? []
                Section {
                    ForEach(topicPapers.prefix(3)) { paper in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(paper.title)
                                .font(.subheadline)
                                .lineLimit(2)
                            Text(paper.displayAuthors)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                    if topicPapers.count > 3 {
                        Text("+ \(topicPapers.count - 3) more paper\(topicPapers.count - 3 == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                    startInterviewButton(papers: topicPapers, topic: topic)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    HStack {
                        Text(topic)
                        Spacer()
                        Text("\(topicPapers.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(selectedCompany ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !svc.isPro {
                freeTierBanner
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation { selectedCompany = nil }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Companies")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
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
            Image(systemName: "brain.head.profile")
                .foregroundStyle(.indigo)
            Text("\(credits.remainingInterviewSessions) mock session\(credits.remainingInterviewSessions == 1 ? "" : "s") left this month")
                .font(.subheadline)
            Spacer()
            Button("Go Pro") { showPaywall = true }
                .font(.subheadline.bold())
                .foregroundStyle(.indigo)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
