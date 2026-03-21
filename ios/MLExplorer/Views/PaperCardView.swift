import SwiftUI

struct PaperCardView: View {
    let paper: Paper
    @EnvironmentObject var bookmarks: BookmarkStore

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar — score tier indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(scoreColor)
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 7) {

                // Row 1: ML Score + source badge + year
                HStack(spacing: 6) {
                    // ML Score badge
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

                    if let source = paper.source {
                        Text(source.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(source == "arxiv" ? Color.blue : Color.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                (source == "arxiv" ? Color.blue : Color.green).opacity(0.12),
                                in: Capsule()
                            )
                    }

                    if let venue = paper.venue, !venue.isEmpty {
                        Text(venue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if let year = paper.year {
                        Text(String(year))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }

                // Row 2: Title — primary content, max 2 lines
                Text(paper.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Row 3: Authors (muted, single line)
                Text(paper.displayAuthors)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Row 4: Topic chip + citations + bookmark
                HStack(spacing: 6) {
                    if let topic = paper.topic {
                        Text(topic)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                    }

                    // Company chips (max 2)
                    ForEach((paper.companies ?? []).prefix(2), id: \.self) { company in
                        Text(company)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                    }

                    Spacer()

                    // Citations
                    if let c = paper.citations, c > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 10))
                            Text(formatCount(c))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.tertiary)
                    }

                    // Bookmark
                    Button {
                        bookmarks.toggle(paper)
                    } label: {
                        Image(systemName: bookmarks.isBookmarked(paper) ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 13))
                            .foregroundStyle(bookmarks.isBookmarked(paper) ? Color.yellow : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 13)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var scoreColor: Color {
        switch paper.score ?? 0 {
        case 75...: return .green
        case 55..<75: return .orange
        default: return Color(.systemGray3)
        }
    }

    private func formatCount(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }
}
