import Foundation
import Combine

@MainActor
class PapersViewModel: ObservableObject {
    @Published var papers: [Paper] = []
    @Published var filteredPapers: [Paper] = []
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
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Debounce all filter inputs — wait 200ms after last change before filtering
        Publishers.CombineLatest4(
            $searchText.debounce(for: .milliseconds(200), scheduler: DispatchQueue.main),
            $selectedTopic,
            $selectedCompany,
            $sortBy
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.applyFilters()
        }
        .store(in: &cancellables)
    }

    var allTopics: [String] {
        ["All"] + Array(Set(papers.compactMap { $0.topic })).sorted()
    }

    var allCompanies: [String] {
        ["All"] + Array(Set(papers.flatMap { $0.companies ?? [] })).sorted()
    }

    var statsText: String {
        let total = filteredPapers.count
        let topics = Set(filteredPapers.compactMap { $0.topic }).count
        return "\(total) papers · \(topics) topics"
    }

    private func applyFilters() {
        let query = searchText.lowercased()
        let topic = selectedTopic
        let company = selectedCompany
        let sort = sortBy
        let source = papers

        Task.detached(priority: .userInitiated) {
            var result = source

            if topic != "All" {
                result = result.filter { $0.topic == topic }
            }
            if company != "All" {
                result = result.filter { $0.companies?.contains(company) == true }
            }
            if !query.isEmpty {
                result = result.filter {
                    $0.title.lowercased().contains(query) ||
                    ($0.abstract?.lowercased().contains(query) == true) ||
                    ($0.topic?.lowercased().contains(query) == true) ||
                    $0.authors.joined(separator: " ").lowercased().contains(query)
                }
            }

            switch sort {
            case .score:     result.sort { ($0.score ?? 0) > ($1.score ?? 0) }
            case .citations: result.sort { ($0.citations ?? 0) > ($1.citations ?? 0) }
            case .recent:    result.sort { ($0.year ?? 0) > ($1.year ?? 0) }
            }

            await MainActor.run { [result] in
                self.filteredPapers = result
            }
        }
    }

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("papers_cache.json")
    }

    func load() async {
        // Load cache instantly so UI is never empty
        if papers.isEmpty, let cached = loadCache() {
            papers = cached
            applyFilters()
        }
        isLoading = true
        errorMessage = nil
        do {
            let url = URL(string: papersURL)!
            let (data, _) = try await URLSession.shared.data(from: url)
            let fresh = try JSONDecoder().decode([Paper].self, from: data)
            papers = fresh
            applyFilters()
            saveCache(data)
        } catch {
            if papers.isEmpty {
                errorMessage = "No internet connection and no cached data."
            }
            // If we have cache, silently ignore the error
        }
        isLoading = false
    }

    private func loadCache() -> [Paper]? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode([Paper].self, from: data)
    }

    private func saveCache(_ data: Data) {
        try? data.write(to: cacheURL)
    }

    func resetFilters() {
        searchText = ""
        selectedTopic = "All"
        selectedCompany = "All"
        sortBy = .score
    }
}
