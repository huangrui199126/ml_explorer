import Foundation
import CryptoKit

// MARK: - Shared Cache File stored on GitHub Pages
// Path:  insights/{paperKey}.json
// Read:  https://huangrui199126.github.io/ml_explorer/insights/{paperKey}.json
// Write: GitHub Contents API (requires PAT with contents:write)

// MARK: - Response shapes (what Claude actually returns)

private struct FastInsightResponse: Decodable {
    let summary: String
    let keyIdea: String
    let whyItMatters: String
    let possibleUseCases: [String]

    enum CodingKeys: String, CodingKey {
        case summary
        case keyIdea = "key_idea"
        case whyItMatters = "why_it_matters"
        case possibleUseCases = "possible_use_cases"
    }
}

private struct DeepInsightResponse: Decodable {
    let methodBreakdown: String
    let keyInnovation: String
    let technicalInsight: String
    let limitations: String
    let interviewQuestions: [String]
    let interviewAnswers: [String]

    enum CodingKeys: String, CodingKey {
        case methodBreakdown = "method_breakdown"
        case keyInnovation = "key_innovation"
        case technicalInsight = "technical_insight"
        case limitations
        case interviewQuestions = "interview_questions"
        case interviewAnswers = "interview_answers"
    }
}

// MARK: - Shared insight file (both fast + deep in one JSON)

struct SharedInsightFile: Codable {
    var fast: FastInsight?
    var deep: DeepInsight?
}

// MARK: - Service

actor InsightService {
    static let shared = InsightService()

    // Keys stored only on developer device (Mac mini batch script uses env var, not app)
    private var anthropicKey: String { UserDefaults.standard.string(forKey: "anthropic_api_key") ?? "" }

    private let repoOwner = "huangrui199126"
    private let repoName  = "ml_explorer"
    private let pagesBase = "https://huangrui199126.github.io/ml_explorer"

    // MARK: - Paper key (stable filename)

    /// Stable filename for a paper: arXiv ID if available, else SHA256 of title.
    /// nonisolated so views can call it synchronously without await.
    nonisolated func paperKey(for paper: Paper) -> String {
        Self.paperKey(for: paper)
    }

    /// Static version callable from anywhere (views, free functions).
    static func paperKey(for paper: Paper) -> String {
        if let url = paper.url,
           let range = url.range(of: #"\d{4}\.\d{4,5}"#, options: .regularExpression) {
            return "arxiv_" + String(url[range]).replacingOccurrences(of: ".", with: "_")
        }
        let hash = SHA256.hash(data: Data(paper.title.utf8))
        return "paper_" + hash.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Index cache (set of inferred keys)

    private var indexedKeys: Set<String>? = nil
    private var indexLoadedAt: Date? = nil

    private func loadIndexIfNeeded() async {
        let needsReload = indexedKeys == nil ||
            indexLoadedAt.map { Date().timeIntervalSince($0) > 3600 } == true
        guard needsReload else { return }
        let url = URL(string: "\(pagesBase)/insights/index.json")!
        if let (data, resp) = try? await URLSession.shared.data(from: url),
           (resp as? HTTPURLResponse)?.statusCode == 200,
           let keys = try? JSONDecoder().decode([String].self, from: data) {
            indexedKeys   = Set(keys)
            indexLoadedAt = Date()
        }
    }

    // MARK: - Shared cache fetch (GitHub Pages CDN)

    func fetchSharedInsight(for paper: Paper) async -> SharedInsightFile? {
        let key = paperKey(for: paper)
        let url = URL(string: "\(pagesBase)/insights/\(key).json")!
        guard let (data, resp) = try? await URLSession.shared.data(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SharedInsightFile.self, from: data)
    }

    /// Fetch the index and return all known inferred keys.
    func fetchIndexedKeys() async -> Set<String> {
        await loadIndexIfNeeded()
        return indexedKeys ?? []
    }

    // MARK: - Fast Insight generation

    func generateFastInsight(for paper: Paper) async throws -> FastInsight {
        let prompt = """
        Analyze this ML paper. Return ONLY valid JSON — no markdown, no explanation.

        Title: \(paper.title)
        Authors: \(paper.authors.prefix(5).joined(separator: ", "))
        Topic: \(paper.topic ?? "Machine Learning")
        Abstract: \(paper.abstract ?? "No abstract available.")

        Return exactly:
        {
          "summary": "1-2 sentence plain English summary",
          "key_idea": "The core technical intuition in one sentence",
          "why_it_matters": "Why practitioners should care — practical importance",
          "possible_use_cases": ["use case 1", "use case 2", "use case 3"]
        }
        """
        let text = try await callClaude(prompt: prompt, model: "claude-haiku-4-5-20251001", maxTokens: 600)
        let resp = try parseJSON(FastInsightResponse.self, from: text)
        return FastInsight(summary: resp.summary, keyIdea: resp.keyIdea,
                           whyItMatters: resp.whyItMatters, possibleUseCases: resp.possibleUseCases,
                           generatedAt: Date())
    }

    // MARK: - Deep Insight generation

    func generateDeepInsight(for paper: Paper, pdfText: String?) async throws -> DeepInsight {
        let context = [pdfText, paper.abstract].compactMap { $0 }.first ?? "No content available."
        let prompt = """
        You are an expert ML researcher and senior engineer. Analyze this paper deeply.
        Return ONLY valid JSON — no markdown, no explanation.

        Title: \(paper.title)
        Topic: \(paper.topic ?? "ML")

        Content (introduction + conclusion):
        \(String(context.prefix(6000)))

        Return exactly:
        {
          "method_breakdown": "How the method works technically — 2-3 sentences",
          "key_innovation": "What is genuinely new vs prior work — 1-2 sentences",
          "technical_insight": "The most important design choice and why it works",
          "limitations": "Main limitations or failure cases",
          "interview_questions": ["Q1?", "Q2?", "Q3?", "Q4?", "Q5?"],
          "interview_answers": ["A1", "A2", "A3", "A4", "A5"]
        }
        """
        let text = try await callClaude(prompt: prompt, model: "claude-sonnet-4-6", maxTokens: 1500)
        let resp = try parseJSON(DeepInsightResponse.self, from: text)
        return DeepInsight(methodBreakdown: resp.methodBreakdown, keyInnovation: resp.keyInnovation,
                           technicalInsight: resp.technicalInsight, limitations: resp.limitations,
                           interviewQuestions: resp.interviewQuestions, interviewAnswers: resp.interviewAnswers,
                           generatedAt: Date())
    }

    // MARK: - Claude API

    private func callClaude(prompt: String, model: String, maxTokens: Int) async throws -> String {
        guard !anthropicKey.isEmpty else { throw InsightError.noApiKey }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anthropicKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw InsightError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0): \(bodyStr.prefix(200))")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = ((json?["content"] as? [[String: Any]])?.first?["text"] as? String) ?? ""
        guard !content.isEmpty else { throw InsightError.emptyResponse }
        return content
    }

    // MARK: - JSON parsing (handles markdown code blocks)

    private func parseJSON<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```") {
            clean = clean.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = clean.firstIndex(of: "{"), let end = clean.lastIndex(of: "}") {
            clean = String(clean[start...end])
        }
        guard let data = clean.data(using: .utf8) else { throw InsightError.parseError }
        guard let result = try? JSONDecoder().decode(type, from: data) else { throw InsightError.parseError }
        return result
    }
}

// MARK: - Errors

enum InsightError: LocalizedError {
    case noApiKey, apiError(String), emptyResponse, parseError

    var errorDescription: String? {
        switch self {
        case .noApiKey:        return "Add your Anthropic API key in Settings to enable AI insights."
        case .apiError(let m): return "API error: \(m)"
        case .emptyResponse:   return "AI returned an empty response."
        case .parseError:      return "Could not parse AI response. Please try again."
        }
    }
}
