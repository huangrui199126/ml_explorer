import SwiftUI

struct PaperDetailView: View {
    let paper: Paper
    @State private var showFullAbstract = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Score + tags
                HStack(spacing: 8) {
                    scoreView
                    if let source = paper.source { sourceTag(source) }
                    Spacer()
                    if let year = paper.year { Text(String(year)).font(.subheadline).foregroundStyle(.secondary) }
                }

                // Title
                Text(paper.title)
                    .font(.title3)
                    .fontWeight(.bold)

                // Authors
                if !paper.authors.isEmpty {
                    Text(paper.authors.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Venue
                if let venue = paper.venue, !venue.isEmpty {
                    Label(venue, systemImage: "building.columns")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Companies + tags
                chipRow

                Divider()

                // Summary bullets
                if let bullets = paper.summaryBullets, !bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Summary", systemImage: "text.quote")
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

                // Abstract
                VStack(alignment: .leading, spacing: 8) {
                    Label("Abstract", systemImage: "doc.text")
                        .font(.headline)
                    if let abstract = paper.abstract {
                        Text(abstract)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(showFullAbstract ? nil : 5)
                        Button(showFullAbstract ? "Show less" : "Read more") {
                            withAnimation { showFullAbstract.toggle() }
                        }
                        .font(.footnote)
                    }
                }

                Divider()

                // Stats
                HStack(spacing: 24) {
                    statItem("Citations", value: "\(paper.citations ?? 0)", icon: "quote.opening")
                    statItem("Influential", value: "\(paper.influentialCitations ?? 0)", icon: "star")
                    statItem("Score", value: "\(paper.score ?? 0)", icon: "chart.bar")
                }

                // Open paper button
                if let urlStr = paper.url, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        Label("Open Paper", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(16)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var scoreView: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption)
            Text("\(paper.score ?? 0)")
                .font(.subheadline)
                .fontWeight(.bold)
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
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
