import SwiftUI
import PDFKit

// MARK: - Main PDF Reader

struct PDFReaderView: View {
    let paper: Paper
    @EnvironmentObject var insightStore: InsightStore
    @EnvironmentObject var questionStore: QuestionStore
    @StateObject private var vm: InsightViewModel
    @State private var pdfText: String?
    @State private var showInsights = false
    @State private var showNotes = false
    @State private var isLoadingPDF = true
    @State private var pdfLoadFailed = false

    init(paper: Paper, store: InsightStore) {
        self.paper = paper
        _vm = StateObject(wrappedValue: InsightViewModel(paper: paper, store: store))
    }

    var body: some View {
        ZStack {
            if let pdfURL = paper.pdfURL {
                PDFKitView(url: pdfURL, isLoading: $isLoadingPDF, failed: $pdfLoadFailed, onTextExtracted: { text in
                    pdfText = text
                })
                .ignoresSafeArea(edges: .bottom)

                if isLoadingPDF {
                    loadingOverlay
                }
            } else {
                noPDFView
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .sheet(isPresented: $showInsights) {
            InsightSheetView(vm: vm, paper: paper)
                .environmentObject(insightStore)
                .environmentObject(questionStore)
        }
        .sheet(isPresented: $showNotes) {
            NoteEditorView(paper: paper)
                .environmentObject(insightStore)
        }
        .task {
            // Start fast insight immediately
            await vm.generateFastIfNeeded()
            // Wait 4s for PDF to load and extract text, then run deep
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await vm.generateDeepIfNeeded(pdfText: pdfText)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showNotes = true
            } label: {
                Image(systemName: insightStore.note(for: paper)?.content.isEmpty == false
                      ? "note.text" : "note.text.badge.plus")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showInsights = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                    if vm.isGeneratingFast || vm.isGeneratingDeep {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        insightStateDot
                    }
                }
            }
        }
    }

    private var insightStateDot: some View {
        Circle()
            .fill(vm.deepInsight != nil ? Color.purple :
                    vm.fastInsight != nil ? Color.orange : Color.gray)
            .frame(width: 8, height: 8)
    }

    // MARK: - Supporting views

    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading PDF…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private var noPDFView: some View {
        ContentUnavailableView {
            Label("No PDF Available", systemImage: "doc.slash")
        } description: {
            Text("This paper doesn't have a direct PDF link.\nTry opening it in Safari.")
        } actions: {
            if let urlStr = paper.url, let url = URL(string: urlStr) {
                Link("Open in Safari", destination: url)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - PDFKit Wrapper

struct PDFKitView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var failed: Bool
    var onTextExtracted: ((String) -> Void)?

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor.systemBackground

        Task {
            await loadPDF(into: pdfView)
        }
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}

    private func loadPDF(into pdfView: PDFView) async {
        // Try direct URL first (works for local files and cached PDFs)
        if let doc = PDFDocument(url: url) {
            await apply(doc: doc, to: pdfView)
            return
        }
        // Fallback: fetch with proper headers (needed for some arXiv mirrors)
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let doc = PDFDocument(data: data) else {
            await MainActor.run { isLoading = false; failed = true }
            return
        }
        await apply(doc: doc, to: pdfView)
    }

    private func apply(doc: PDFDocument, to pdfView: PDFView) async {
        await MainActor.run {
            pdfView.document = doc
            isLoading = false
        }
        // Extract text from intro + conclusion pages for deep insight
        let text = extractKeyPages(from: doc)
        await MainActor.run { onTextExtracted?(text) }
    }

    // Extract first 3 + last 2 pages (intro + conclusion)
    private func extractKeyPages(from doc: PDFDocument) -> String {
        let count = doc.pageCount
        let pages = Array(Set(Array(0..<min(3, count)) + Array(max(0, count - 2)..<count)))
            .sorted()
        return pages
            .compactMap { doc.page(at: $0)?.string }
            .joined(separator: "\n\n")
    }
}

// MARK: - Insight Sheet (from toolbar button)

struct InsightSheetView: View {
    @ObservedObject var vm: InsightViewModel
    let paper: Paper
    @EnvironmentObject var insightStore: InsightStore
    @EnvironmentObject var questionStore: QuestionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    QuickInsightCard(vm: vm)
                    if vm.fastInsight != nil || vm.isGeneratingDeep {
                        DeepInsightCard(vm: vm)
                    }
                    if let deep = vm.deepInsight {
                        InterviewPrepCard(deep: deep, paper: paper)
                            .environmentObject(questionStore)
                    }
                    NotePreviewCard(paper: paper)
                        .environmentObject(insightStore)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
