import SwiftUI
import Combine

private let remoteURL = URL(string: "https://huangrui199126.github.io/ml_explorer/ml_challenges.json")!
private let cacheFilename = "ml_challenges_cache.json"

@MainActor
class MLChallengesViewModel: ObservableObject {
    @Published var problems: [MLChallenge] = []
    @Published var filtered: [MLChallenge] = []
    @Published var searchText: String = ""
    @Published var selectedDifficulty: String? = nil
    @Published var selectedCategory: String? = nil
    @Published var categories: [String] = []
    @Published var isLoading = false

    private var cancellables = Set<AnyCancellable>()

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(cacheFilename)
    }

    init() {
        Publishers.CombineLatest3(
            $searchText.debounce(for: .milliseconds(200), scheduler: RunLoop.main),
            $selectedDifficulty,
            $selectedCategory
        )
        .sink { [weak self] search, difficulty, category in
            self?.applyFilter(search: search, difficulty: difficulty, category: category)
        }
        .store(in: &cancellables)
    }

    func load() {
        guard problems.isEmpty else { return }
        isLoading = true

        Task {
            // 1. Show bundled or cached data immediately
            if let local = loadLocal() {
                apply(local)
            }

            // 2. Fetch remote in background and update
            await fetchRemote()
        }
    }

    // MARK: - Local (bundle + cache)

    private func loadLocal() -> MLChallengesData? {
        // Prefer cached (may be newer than bundle)
        if let cached = try? Data(contentsOf: cacheURL),
           let decoded = decode(cached) {
            return decoded
        }
        // Fall back to bundled JSON
        if let url = Bundle.main.url(forResource: "ml_challenges", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = decode(data) {
            return decoded
        }
        return nil
    }

    // MARK: - Remote

    private func fetchRemote() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            guard let decoded = decode(data) else { return }
            // Cache for next launch
            try? data.write(to: cacheURL, options: .atomic)
            // Only update UI if we got more or equal problems (never downgrade)
            if decoded.problems.count >= problems.count {
                apply(decoded)
            }
        } catch {
            // Network unavailable — already showing local data, nothing to do
        }
    }

    // MARK: - Helpers

    private func decode(_ data: Data) -> MLChallengesData? {
        try? JSONDecoder().decode(MLChallengesData.self, from: data)
    }

    private func apply(_ data: MLChallengesData) {
        problems = data.problems
        categories = data.categories
        isLoading = false
        applyFilter(search: searchText, difficulty: selectedDifficulty, category: selectedCategory)
    }

    private func applyFilter(search: String, difficulty: String?, category: String?) {
        var result = problems
        if !search.isEmpty {
            let q = search.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                $0.category.lowercased().contains(q) ||
                $0.description.lowercased().contains(q)
            }
        }
        if let d = difficulty {
            result = result.filter { $0.difficulty.lowercased() == d.lowercased() }
        }
        if let c = category {
            result = result.filter { $0.category == c }
        }
        filtered = result
    }
}
