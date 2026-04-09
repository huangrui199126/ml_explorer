import SwiftUI

struct PaperDetailView: View {
    let paper: Paper
    @EnvironmentObject var bookmarks: BookmarkStore
    @EnvironmentObject var insightStore: InsightStore
    @EnvironmentObject var questionStore: QuestionStore
    @StateObject private var vm: InsightViewModel
    @State private var showFullAbstract = false
    @State private var showPDF = false

    init(paper: Paper, store: InsightStore) {
        self.paper = paper
        _vm = StateObject(wrappedValue: InsightViewModel(paper: paper, store: store))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // MARK: Header
                headerSection

                // MARK: Read Paper Button
                readPaperButton

                Divider()

                // MARK: AI Insights
                QuickInsightCard(vm: vm)
                    .padding(.horizontal, 0)

                CreditStatusBanner()

                if vm.fastInsight != nil || vm.isGeneratingDeep || vm.deepInsight != nil {
                    DeepInsightCard(vm: vm)
                }

                if let deep = vm.deepInsight {
                    InterviewPrepCard(deep: deep, paper: paper)
                        .environmentObject(questionStore)
                }

                Divider()

                // MARK: Notes
                NotePreviewCard(paper: paper)
                    .environmentObject(insightStore)

                Divider()

                // MARK: Summary bullets (static, from papers.json)
                if let bullets = paper.summaryBullets, !bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Paper Summary", systemImage: "text.quote")
                            .font(.headline)
                        ForEach(bullets, id: \.text) { bullet in
                            HStack(alignment: .top, spacing: 8) {
                                Text(bullet.emoji)
                                Text(bullet.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary.opacity(0.9))
                            }
                        }
                    }
                    Divider()
                }

                // MARK: Abstract
                abstractSection

                Divider()

                // MARK: Stats
                statsSection
            }
            .padding(16)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task { await vm.generateFastIfNeeded() }
        .navigationDestination(isPresented: $showPDF) {
            PDFReaderView(paper: paper, store: insightStore)
                .environmentObject(insightStore)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                scoreView
                if let source = paper.source { sourceTag(source) }
                Spacer()
                if let year = paper.year {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(paper.title)
                .font(.title3)
                .fontWeight(.bold)

            if !paper.authors.isEmpty {
                Text(paper.displayAuthors)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let venue = paper.venue, !venue.isEmpty {
                Label(venue, systemImage: "building.columns")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            chipRow
        }
    }

    // MARK: - Read Paper Button

    private var readPaperButton: some View {
        HStack(spacing: 10) {
            if paper.hasPDF {
                Button {
                    showPDF = true
                } label: {
                    Label("Read Paper + AI Insights", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
            } else if let urlStr = paper.url, let url = URL(string: urlStr) {
                Link(destination: url) {
                    Label("Open Paper", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Abstract

    private var abstractSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Abstract", systemImage: "doc.text")
                .font(.headline)
            if let abstract = paper.abstract {
                Text(abstract)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(showFullAbstract ? nil : 4)
                Button(showFullAbstract ? "Show less" : "Read more") {
                    withAnimation { showFullAbstract.toggle() }
                }
                .font(.footnote)
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 24) {
            statItem("Citations",    value: "\(paper.citations ?? 0)",            icon: "quote.opening")
            statItem("Influential",  value: "\(paper.influentialCitations ?? 0)", icon: "star")
            statItem("Score",        value: "\(paper.score ?? 0)",                icon: "chart.bar")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                bookmarks.toggle(paper)
            } label: {
                Image(systemName: bookmarks.isBookmarked(paper) ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(bookmarks.isBookmarked(paper) ? Color.yellow : Color.secondary)
            }
        }
    }

    // MARK: - Small components

    private var scoreView: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill").font(.caption)
            Text("\(paper.score ?? 0)").font(.subheadline).fontWeight(.bold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(scoreColor, in: Capsule())
    }

    private var scoreColor: Color {
        switch paper.score ?? 0 {
        case 70...: return .green
        case 50..<70: return .orange
        default: return .gray
        }
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if let topic = paper.topic { chip(topic, color: .purple) }
                ForEach(paper.companies ?? [], id: \.self) { c in chip(c, color: .orange) }
                ForEach(paper.knowledgeTags ?? [], id: \.self) { t in chip(t, color: .teal) }
            }
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
    }

    private func sourceTag(_ source: String) -> some View {
        Text(source.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(source == "arxiv" ? Color.blue : Color.green)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (source == "arxiv" ? Color.blue : Color.green).opacity(0.15),
                in: RoundedRectangle(cornerRadius: 4)
            )
    }

    private func statItem(_ label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(value).font(.headline)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
