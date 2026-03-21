import Foundation
import Combine

@MainActor
class PapersViewModel: ObservableObject {
    @Published var papers: [Paper] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedTopic = "All"
    @Published var selectedCompany = "All"
    @Published var sortBy: SortOption = .score

    enum SortOption: String, CaseIterable, Identifiable {
        case score = "Score"
        case citations = "Citations"
        case recent = "Recent"
        var id: String { rawValue }
    }

    private let papersURL = "https://huangrui199126.github.io/ml_explorer/papers.json"

    var allTopics: [String] {
        ["All"] + Array(Set(papers.compactMap { $0.topic })).sorted()
    }

    var allCompanies: [String] {
        ["All"] + Array(Set(papers.flatMap { $0.companies ?? [] })).sorted()
    }

    var filteredPapers: [Paper] {
        var result = papers

        if selectedTopic != "All" {
            result = result.filter { $0.topic == selectedTopic }
        }
        if selectedCompany != "All" {
            result = result.filter { $0.companies?.contains(selectedCompany) == true }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                ($0.abstract?.lowercased().contains(q) == true) ||
                ($0.topic?.lowercased().contains(q) == true) ||
                $0.authors.joined(separator: " ").lowercased().contains(q)
            }
        }

        switch sortBy {
        case .score:      result.sort { ($0.score ?? 0) > ($1.score ?? 0) }
        case .citations:  result.sort { ($0.citations ?? 0) > ($1.citations ?? 0) }
        case .recent:     result.sort { ($0.year ?? 0) > ($1.year ?? 0) }
        }

        return result
    }

    var statsText: String {
        let total = filteredPapers.count
        let topics = Set(filteredPapers.compactMap { $0.topic }).count
        return "\(total) papers · \(topics) topics"
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let url = URL(string: papersURL)!
            let (data, _) = try await URLSession.shared.data(from: url)
            papers = try JSONDecoder().decode([Paper].self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func resetFilters() {
        searchText = ""
        selectedTopic = "All"
        selectedCompany = "All"
        sortBy = .score
    }
}
