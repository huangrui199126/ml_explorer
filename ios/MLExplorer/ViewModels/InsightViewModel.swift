import Foundation

@MainActor
class InsightViewModel: ObservableObject {
    @Published var fastInsight: FastInsight?
    @Published var deepInsight: DeepInsight?
    @Published var isGeneratingFast = false
    @Published var isGeneratingDeep = false
    @Published var fastError: String?
    @Published var deepError: String?

    private let paper: Paper
    private let store: InsightStore
    private let service = InsightService.shared

    var insightState: InsightState {
        if deepInsight != nil { return .deepReady }
        if fastInsight != nil { return .fastReady }
        return .none
    }

    init(paper: Paper, store: InsightStore) {
        self.paper = paper
        self.store = store
        // Load local cache instantly (no network)
        if let cached = store.insight(for: paper) {
            fastInsight = cached.fast
            deepInsight = cached.deep
        }
    }

    // MARK: - Entry point: check shared → local → generate

    func generateFastIfNeeded() async {
        guard fastInsight == nil else { return }

        // 1. Check shared GitHub Pages cache first (free, no API call)
        if let shared = await service.fetchSharedInsight(for: paper) {
            if let fast = shared.fast {
                fastInsight = fast
                if let deep = shared.deep { deepInsight = deep }
                persistAll()
                return   // Already have everything — done
            }
        }

        // 2. Not cached anywhere — generate via API
        await generateFast()
    }

    func generateDeepIfNeeded(pdfText: String? = nil) async {
        guard deepInsight == nil, !isGeneratingDeep else { return }
        // Wait for fast to finish
        while isGeneratingFast { try? await Task.sleep(nanoseconds: 200_000_000) }
        await generateDeep(pdfText: pdfText)
    }

    func retryFast() async { fastError = nil; await generateFast() }
    func retryDeep(pdfText: String? = nil) async { deepError = nil; deepInsight = nil; await generateDeep(pdfText: pdfText) }

    // MARK: - Private generation

    private func generateFast() async {
        // No API key — show hint, not error
        let key = UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""
        guard !key.isEmpty else { return }

        isGeneratingFast = true
        fastError = nil
        do {
            let insight = try await service.generateFastInsight(for: paper)
            fastInsight = insight
            persistFast(insight)
        } catch {
            fastError = error.localizedDescription
        }
        isGeneratingFast = false
    }

    private func generateDeep(pdfText: String?) async {
        isGeneratingDeep = true
        deepError = nil
        do {
            let insight = try await service.generateDeepInsight(for: paper, pdfText: pdfText)
            deepInsight = insight
            persistDeep(insight)
        } catch {
            deepError = error.localizedDescription
        }
        isGeneratingDeep = false
    }

    // MARK: - Local persistence

    private func persistAll() {
        var container = PaperInsight(paperId: paper.id, state: deepInsight != nil ? .deepReady : .fastReady)
        container.fast = fastInsight
        container.deep = deepInsight
        store.save(insight: container)
    }

    private func persistFast(_ insight: FastInsight) {
        var container = store.insight(for: paper) ?? PaperInsight(paperId: paper.id, state: .fastReady)
        container.fast = insight
        container.state = .fastReady
        store.save(insight: container)
    }

    private func persistDeep(_ insight: DeepInsight) {
        var container = store.insight(for: paper) ?? PaperInsight(paperId: paper.id, state: .deepReady)
        container.deep = insight
        container.state = .deepReady
        store.save(insight: container)
    }
}
