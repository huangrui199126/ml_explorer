import SwiftUI

struct PaperListView: View {
    @StateObject private var vm = PapersViewModel()
    @StateObject private var bookmarks = BookmarkStore()
    @State private var showFilters = false
    @State private var showBookmarks = false
    @State private var searchPlaceholderIndex = 0

    private let placeholders = [
        "Search papers, e.g. 'two-tower retrieval'",
        "Try 'Google recommendation 2024'",
        "Search 'transformer CTR prediction'",
        "Try 'LLM alignment RLHF'",
        "Search by company, e.g. 'Pinterest'",
    ]

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.papers.isEmpty {
                    loadingView
                } else if let error = vm.errorMessage, vm.papers.isEmpty {
                    errorView(error)
                } else {
                    mainContent
                }
            }
            .navigationTitle("ML Explorer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .searchable(
                text: $vm.searchText,
                prompt: placeholders[searchPlaceholderIndex]
            )
        }
        .environmentObject(bookmarks)
        .task { await vm.load() }
        .sheet(isPresented: $showFilters) {
            FilterSheetView(vm: vm)
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksView(vm: vm)
                .environmentObject(bookmarks)
        }
        .onAppear {
            // Rotate placeholder every 3s
            Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                withAnimation {
                    searchPlaceholderIndex = (searchPlaceholderIndex + 1) % placeholders.count
                }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        List {
            // Daily Picks section (only when not searching/filtering)
            if vm.searchText.isEmpty && vm.selectedTopic == "All" && vm.selectedCompany == "All" {
                Section {
                    DailyPicksView(papers: vm.papers)
                        .environmentObject(bookmarks)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            // Stats bar
            Section {
                HStack {
                    Text(vm.statsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if hasActiveFilters {
                        Button("Clear") { vm.resetFilters() }
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // Paper cards
            ForEach(vm.filteredPapers) { paper in
                NavigationLink(destination: PaperDetailView(paper: paper).environmentObject(bookmarks)) {
                    PaperCardView(paper: paper)
                        .environmentObject(bookmarks)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
        .refreshable { await vm.load() }
        .overlay(alignment: .top) {
            if vm.isLoading && !vm.papers.isEmpty {
                ProgressView()
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Supporting Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Loading papers…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't load papers", systemImage: "wifi.slash")
        } description: {
            Text(error)
        } actions: {
            Button("Retry") { Task { await vm.load() } }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showBookmarks = true
            } label: {
                Image(systemName: bookmarks.bookmarkedIDs.isEmpty ? "bookmark" : "bookmark.fill")
                    .symbolVariant(bookmarks.bookmarkedIDs.isEmpty ? .none : .fill)
                    .foregroundStyle(bookmarks.bookmarkedIDs.isEmpty ? .secondary : .yellow)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showFilters = true } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .symbolVariant(hasActiveFilters ? .fill : .none)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort by", selection: $vm.sortBy) {
                    ForEach(PapersViewModel.SortOption.allCases) { opt in
                        Label(opt.rawValue, systemImage: opt.icon).tag(opt)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
        }
    }

    private var hasActiveFilters: Bool {
        vm.selectedTopic != "All" || vm.selectedCompany != "All"
    }
}
