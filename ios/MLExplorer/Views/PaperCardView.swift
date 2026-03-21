import SwiftUI

struct PaperCardView: View {
    let paper: Paper

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row: score badge + source tag
            HStack(alignment: .top) {
                scoreBadge
                Spacer()
                if let source = paper.source {
                    sourceTag(source)
                }
            }

            // Title
            Text(paper.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // Authors + year
            HStack {
                Text(paper.displayAuthors)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let year = paper.year {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Topic + venue chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if let topic = paper.topic {
                        chip(topic, color: .purple)
                    }
                    if let venue = paper.venue, !venue.isEmpty {
                        chip(venue, color: .blue)
                    }
                    ForEach(paper.companies ?? [], id: \.self) { c in
                        chip(c, color: .orange)
                    }
                }
            }

            // Citations
            if let c = paper.citations, c > 0 {
                Label("\(c) citations", systemImage: "quote.opening")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var scoreBadge: some View {
        Text("\(paper.score ?? 0)")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(scoreColor, in: Capsule())
    }

    private var scoreColor: Color {
        switch paper.score ?? 0 {
        case 70...: return .green
        case 50..<70: return .orange
        default: return .gray
        }
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

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }
}
