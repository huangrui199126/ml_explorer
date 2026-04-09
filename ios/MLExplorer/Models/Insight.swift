import Foundation
import SwiftUI

// MARK: - States

enum InsightState: String, Codable {
    case none, fastReady, deepReady
}

// MARK: - Fast Insight (from abstract, ~1s, Haiku)

struct FastInsight: Codable {
    let summary: String
    let keyIdea: String
    let whyItMatters: String
    let possibleUseCases: [String]
    let generatedAt: Date

    enum CodingKeys: String, CodingKey {
        case summary
        case keyIdea = "key_idea"
        case whyItMatters = "why_it_matters"
        case possibleUseCases = "possible_use_cases"
        case generatedAt = "generated_at"
    }
}

// MARK: - Deep Insight (from PDF content, async, Sonnet)

struct DeepInsight: Codable {
    let methodBreakdown: String
    let keyInnovation: String
    let technicalInsight: String
    let limitations: String
    let interviewQuestions: [String]
    let interviewAnswers: [String]
    let generatedAt: Date

    enum CodingKeys: String, CodingKey {
        case methodBreakdown = "method_breakdown"
        case keyInnovation = "key_innovation"
        case technicalInsight = "technical_insight"
        case limitations
        case interviewQuestions = "interview_questions"
        case interviewAnswers = "interview_answers"
        case generatedAt = "generated_at"
    }
}

// MARK: - Container stored per paper

struct PaperInsight: Codable {
    var paperId: String
    var state: InsightState
    var fast: FastInsight?
    var deep: DeepInsight?
}

// MARK: - User Notes

struct PaperNote: Codable, Identifiable {
    var id: UUID
    var paperId: String
    var content: String
    var updatedAt: Date

    init(paperId: String, content: String = "") {
        self.id = UUID()
        self.paperId = paperId
        self.content = content
        self.updatedAt = Date()
    }
}

// MARK: - Interview Question Status

enum QuestionStatus: String, Codable, CaseIterable {
    case new      = "New"
    case learning = "Learning"
    case mastered = "Mastered"

    var icon: String {
        switch self {
        case .new:      return "sparkle"
        case .learning: return "book.fill"
        case .mastered: return "checkmark.seal.fill"
        }
    }

    var color: Color {
        switch self {
        case .new:      return .orange
        case .learning: return .blue
        case .mastered: return .green
        }
    }

    var next: QuestionStatus {
        switch self {
        case .new:      return .learning
        case .learning: return .mastered
        case .mastered: return .new
        }
    }
}

// MARK: - Saved Interview Question

struct SavedQuestion: Codable, Identifiable {
    var id: UUID
    var paperId: String
    var paperTitle: String
    var question: String
    var answer: String
    var status: QuestionStatus
    var savedAt: Date
    var lastReviewedAt: Date?

    init(paperId: String, paperTitle: String, question: String, answer: String) {
        self.id = UUID()
        self.paperId = paperId
        self.paperTitle = paperTitle
        self.question = question
        self.answer = answer
        self.status = .new
        self.savedAt = Date()
    }
}

// MARK: - Question Store

@MainActor
class QuestionStore: ObservableObject {
    @Published private(set) var questions: [SavedQuestion] = []

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("ml_questions.json")
        load()
    }

    func isSaved(question: String, paperId: String) -> Bool {
        questions.contains { $0.question == question && $0.paperId == paperId }
    }

    func toggle(question: String, answer: String, paperId: String, paperTitle: String) {
        if let idx = questions.firstIndex(where: { $0.question == question && $0.paperId == paperId }) {
            questions.remove(at: idx)
        } else {
            questions.append(SavedQuestion(paperId: paperId, paperTitle: paperTitle,
                                           question: question, answer: answer))
        }
        persist()
    }

    func advanceStatus(_ id: UUID) {
        guard let idx = questions.firstIndex(where: { $0.id == id }) else { return }
        questions[idx].status = questions[idx].status.next
        questions[idx].lastReviewedAt = Date()
        persist()
    }

    func setStatus(_ id: UUID, status: QuestionStatus) {
        guard let idx = questions.firstIndex(where: { $0.id == id }) else { return }
        questions[idx].status = status
        questions[idx].lastReviewedAt = Date()
        persist()
    }

    func delete(_ id: UUID) {
        questions.removeAll { $0.id == id }
        persist()
    }

    var newCount:      Int { questions.filter { $0.status == .new }.count }
    var learningCount: Int { questions.filter { $0.status == .learning }.count }
    var masteredCount: Int { questions.filter { $0.status == .mastered }.count }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([SavedQuestion].self, from: data) else { return }
        questions = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(questions) {
            try? data.write(to: fileURL)
        }
    }
}

// MARK: - Insight Store

@MainActor
class InsightStore: ObservableObject {
    @Published private(set) var insights: [String: PaperInsight] = [:]
    @Published private(set) var notes: [String: PaperNote] = [:]

    private let insightsURL: URL
    private let notesURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        insightsURL = docs.appendingPathComponent("ml_insights.json")
        notesURL = docs.appendingPathComponent("ml_notes.json")
        load()
    }

    func insight(for paper: Paper) -> PaperInsight? { insights[paper.id] }
    func note(for paper: Paper) -> PaperNote? { notes[paper.id] }

    func save(insight: PaperInsight) {
        insights[insight.paperId] = insight
        persist()
    }

    func saveNote(paperId: String, content: String) {
        if var existing = notes[paperId] {
            existing.content = content
            existing.updatedAt = Date()
            notes[paperId] = existing
        } else {
            notes[paperId] = PaperNote(paperId: paperId, content: content)
        }
        persistNotes()
    }

    private func load() {
        if let data = try? Data(contentsOf: insightsURL),
           let decoded = try? JSONDecoder().decode([String: PaperInsight].self, from: data) {
            insights = decoded
        }
        if let data = try? Data(contentsOf: notesURL),
           let decoded = try? JSONDecoder().decode([String: PaperNote].self, from: data) {
            notes = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(insights) {
            try? data.write(to: insightsURL)
        }
    }

    private func persistNotes() {
        if let data = try? JSONEncoder().encode(notes) {
            try? data.write(to: notesURL)
        }
    }
}
