import SwiftUI
import Combine

private let remoteURL = URL(string: "https://huangrui199126.github.io/ml_explorer/ml_system_design.json")!
private let cacheFilename = "ml_system_design_cache.json"

@MainActor
class MLSystemDesignViewModel: ObservableObject {
    @Published var problems: [MLSDProblem] = []
    @Published var categories: [MLSDCategory] = []
    @Published var filtered: [MLSDProblem] = []
    @Published var searchText: String = ""
    @Published var selectedCategory: String? = nil
    @Published var selectedDifficulty: String? = nil
    @Published var isLoading = false

    private var cancellables = Set<AnyCancellable>()

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(cacheFilename)
    }

    init() {
        Publishers.CombineLatest3(
            $searchText.debounce(for: .milliseconds(200), scheduler: RunLoop.main),
            $selectedCategory,
            $selectedDifficulty
        )
        .sink { [weak self] search, cat, diff in
            self?.applyFilter(search: search, category: cat, difficulty: diff)
        }
        .store(in: &cancellables)
    }

    func load() {
        guard problems.isEmpty else { return }
        isLoading = true

        Task {
            // 1. Show cached or bundled data immediately
            if let local = loadLocal() {
                apply(local)
            }

            // 2. Fetch remote in background and update
            await fetchRemote()
        }
    }

    // MARK: - Local (cache first, then bundle)

    private func loadLocal() -> MLSDData? {
        if let data = try? Data(contentsOf: cacheURL),
           let decoded = try? JSONDecoder().decode(MLSDData.self, from: data) {
            return decoded
        }
        if let url = Bundle.main.url(forResource: "ml_system_design", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(MLSDData.self, from: data) {
            return decoded
        }
        return nil
    }

    // MARK: - Remote

    private func fetchRemote() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            guard let decoded = try? JSONDecoder().decode(MLSDData.self, from: data) else { return }
            // Cache for next launch
            try? data.write(to: cacheURL, options: .atomic)
            // Only update if we got equal or more problems
            if decoded.problems.count >= problems.count {
                apply(decoded)
            }
        } catch {
            // Network unavailable — already showing local data
        }
    }

    // MARK: - Helpers

    func problems(for category: MLSDCategory) -> [MLSDProblem] {
        problems.filter { $0.category == category.name }
    }

    private func apply(_ data: MLSDData) {
        problems = data.problems
        categories = data.categories
        isLoading = false
        applyFilter(search: searchText, category: selectedCategory, difficulty: selectedDifficulty)
    }

    private func applyFilter(search: String, category: String?, difficulty: String?) {
        var result = problems
        if !search.isEmpty {
            let q = search.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                $0.category.lowercased().contains(q) ||
                $0.description.lowercased().contains(q) ||
                $0.companies.contains(where: { $0.lowercased().contains(q) })
            }
        }
        if let c = category {
            result = result.filter { $0.category == c }
        }
        if let d = difficulty {
            result = result.filter { $0.difficulty.lowercased() == d }
        }
        filtered = result
    }
}
