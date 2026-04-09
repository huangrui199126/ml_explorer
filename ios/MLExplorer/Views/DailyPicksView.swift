import SwiftUI

struct DailyPicksView: View {
    let papers: [Paper]
    @EnvironmentObject var bookmarks: BookmarkStore
    @EnvironmentObject var insightStore: InsightStore
    @EnvironmentObject var questionStore: QuestionStore

    // Deterministic daily selection — rotates each day
    private var dailyPapers: [Paper] {
        guard !papers.isEmpty else { return [] }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let topPapers = papers.filter { ($0.score ?? 0) >= 70 }
        guard !topPapers.isEmpty else { return Array(papers.prefix(5)) }
        let start = (day * 7) % topPapers.count
        var result: [Paper] = []
        for i in 0..<5 {
            result.append(topPapers[(start + i) % topPapers.count])
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Daily Picks")
                    .font(.headline)
                Spacer()
                Text("Refreshes daily")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(dailyPapers) { paper in
                        NavigationLink(destination: PaperDetailView(paper: paper, store: insightStore).environmentObject(bookmarks).environmentObject(insightStore).environmentObject(questionStore)) {
                            DailyPickCard(paper: paper)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
}

struct DailyPickCard: View {
    let paper: Paper
    @EnvironmentObject var bookmarks: BookmarkStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Score
            HStack {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(paper.score ?? 0)")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(scoreColor, in: Capsule())

                Spacer()

                Button {
                    bookmarks.toggle(paper)
                } label: {
                    Image(systemName: bookmarks.isBookmarked(paper) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 13))
                        .foregroundStyle(bookmarks.isBookmarked(paper) ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.plain)
            }

            // Title
            Text(paper.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Topic
            if let topic = paper.topic {
                Text(topic)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            }

            // Year + citations
            HStack {
                Text(String(paper.year ?? 2024))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                if let c = paper.citations, c > 0 {
                    Text("\(c >= 1000 ? String(format: "%.1fk", Double(c)/1000) : "\(c)") cites")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(width: 200, height: 160)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(scoreColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var scoreColor: Color {
        switch paper.score ?? 0 {
        case 75...: return .green
        case 55..<75: return .orange
        default: return Color(.systemGray3)
        }
    }
}
