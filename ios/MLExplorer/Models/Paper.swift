import Foundation

struct Paper: Codable, Identifiable {
    var id: String { title }

    let title: String
    let abstract: String?
    let authors: [String]
    let date: String?
    let year: Int?
    let venue: String?
    let source: String?
    let url: String?
    let citations: Int?
    let influentialCitations: Int?
    let categories: [String]?
    let topic: String?
    let score: Int?
    let companies: [String]?
    let knowledgeTags: [String]?
    let summary: String?
    let summaryBullets: [SummaryBullet]?

    enum CodingKeys: String, CodingKey {
        case title, abstract, authors, date, year, venue, source, url
        case citations
        case influentialCitations = "influential_citations"
        case categories, topic, score, companies
        case knowledgeTags = "knowledge_tags"
        case summary
        case summaryBullets = "summary_bullets"
    }

    var scoreColor: String {
        switch score ?? 0 {
        case 70...: return "high"
        case 50..<70: return "mid"
        default: return "low"
        }
    }

    var displayAuthors: String {
        if authors.count <= 3 {
            return authors.joined(separator: ", ")
        }
        return authors.prefix(3).joined(separator: ", ") + " +\(authors.count - 3)"
    }

    /// Derives a direct PDF URL where possible (arXiv → pdf link).
    var pdfURL: URL? {
        guard let urlStr = url else { return nil }
        if urlStr.contains("arxiv.org/abs/") {
            return URL(string: urlStr.replacingOccurrences(of: "/abs/", with: "/pdf/"))
        }
        if urlStr.contains("arxiv.org/pdf/") || urlStr.hasSuffix(".pdf") {
            return URL(string: urlStr)
        }
        return nil
    }

    var hasPDF: Bool { pdfURL != nil }
}

struct SummaryBullet: Codable {
    let type: String
    let text: String

    var emoji: String {
        switch type {
        case "problem": return "❓"
        case "method":  return "⚙️"
        case "result":  return "📈"
        default:        return "💡"
        }
    }
}
