import Foundation

@MainActor
class MLSolutionService: ObservableObject {
    @Published var solution: MLSolution? = nil
    @Published var isLoading = false
    @Published var error: String? = nil

    private let pagesBase = "https://huangrui199126.github.io/ml_explorer/solutions"

    private var cacheDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ml_solutions")
    }

    func load(id: String) async {
        guard solution == nil else { return }
        isLoading = true
        error = nil

        // 1. Check local cache
        let cacheFile = cacheDir.appendingPathComponent("\(id).json")
        if let cached = try? Data(contentsOf: cacheFile),
           let decoded = try? JSONDecoder().decode(MLSolution.self, from: cached) {
            solution = decoded
            isLoading = false
            return
        }

        // 2. Fetch from GitHub Pages
        guard let url = URL(string: "\(pagesBase)/\(id).json") else {
            error = "Invalid URL"
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                error = "Solution not yet available"
                isLoading = false
                return
            }
            let decoded = try JSONDecoder().decode(MLSolution.self, from: data)
            // Cache it
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            try? data.write(to: cacheFile, options: .atomic)
            solution = decoded
        } catch {
            self.error = "Solution not yet available"
        }
        isLoading = false
    }
}
