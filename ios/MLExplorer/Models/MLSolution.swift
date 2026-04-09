import Foundation

struct MLSolution: Codable {
    let id: String
    let python: LanguageSolution?
    let numpy: LanguageSolution?
    let tensorflow: LanguageSolution?
    let pytorch: LanguageSolution?

    var availableLanguages: [(key: String, label: String, solution: LanguageSolution)] {
        var result: [(String, String, LanguageSolution)] = []
        if let s = python     { result.append(("python",     "Python",     s)) }
        if let s = numpy      { result.append(("numpy",      "NumPy",      s)) }
        if let s = tensorflow { result.append(("tensorflow", "TensorFlow", s)) }
        if let s = pytorch    { result.append(("pytorch",    "PyTorch",    s)) }
        return result
    }
}

struct LanguageSolution: Codable {
    let code: String
    let explanation: String
    let keyLearnings: [String]

    enum CodingKeys: String, CodingKey {
        case code, explanation
        case keyLearnings = "key_learnings"
    }
}
