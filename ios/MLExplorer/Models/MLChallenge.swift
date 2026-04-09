import SwiftUI

struct MLChallenge: Codable, Identifiable {
    let id: String
    let title: String
    let category: String
    let difficulty: String
    let description: String
    let example: MLExample
    let learnSection: String
    let starterCode: String

    enum CodingKeys: String, CodingKey {
        case id, title, category, difficulty, description, example
        case learnSection = "learn_section"
        case starterCode = "starter_code"
    }

    var difficultyColor: Color {
        switch difficulty.lowercased() {
        case "easy":   return .green
        case "medium": return .orange
        case "hard":   return .red
        default:       return .secondary
        }
    }

    var difficultyLabel: String { difficulty.capitalized }

    /// Description with the leading title prefix stripped (API sometimes prepends it).
    var cleanDescription: String {
        var text = description
        if text.lowercased().hasPrefix(title.lowercased()) {
            text = String(text.dropFirst(title.count))
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct MLExample: Codable {
    let input: String
    let output: String
    let reasoning: String  // some problems use "explanation" — handled in init

    enum CodingKeys: String, CodingKey {
        case input, output, reasoning, explanation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        input     = (try? c.decodeIfPresent(String.self, forKey: .input))     ?? ""
        output    = (try? c.decodeIfPresent(String.self, forKey: .output))    ?? ""
        reasoning = (try? c.decodeIfPresent(String.self, forKey: .reasoning)) ??
                    (try? c.decodeIfPresent(String.self, forKey: .explanation)) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(input,     forKey: .input)
        try c.encode(output,    forKey: .output)
        try c.encode(reasoning, forKey: .reasoning)
    }
}

struct MLChallengesData: Codable {
    let total: Int
    let categories: [String]
    let problems: [MLChallenge]
}
