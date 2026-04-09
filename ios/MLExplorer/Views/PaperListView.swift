import SwiftUI

struct PaperListView: View {
    @StateObject private var vm = PapersViewModel()
    @StateObject private var bookmarks = BookmarkStore()
    @EnvironmentObject var insightStore: InsightStore
    @EnvironmentObject var questionStore: QuestionStore
    @State private var showFilters = false
    @State private var showBookmarks = false
    @State private var showSettings = false
    @State private var showInterview = false
    @State private var showCompanyPrep = false
    @State private var showChallenges = false
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
                .environmentObject(insightStore)
                .environmentObject(questionStore)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showInterview) {
            InterviewListView()
                .environmentObject(questionStore)
        }
        .sheet(isPresented: $showCompanyPrep) {
            CompanyInterviewView(papers: vm.papers)
                .environmentObject(questionStore)
        }
        .sheet(isPresented: $showChallenges) {
            MLChallengesListView()
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
                        .environmentObject(insightStore)
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
                NavigationLink(destination: PaperDetailView(paper: paper, store: insightStore).environmentObject(bookmarks).environmentObject(insightStore).environmentObject(questionStore)) {
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
            HStack(spacing: 6) {
                UserStatusBadge()
                Button {
                    showBookmarks = true
                } label: {
                    Image(systemName: bookmarks.bookmarkedIDs.isEmpty ? "bookmark" : "bookmark.fill")
                        .foregroundStyle(bookmarks.bookmarkedIDs.isEmpty ? Color.secondary : Color.yellow)
                }
                Button {
                    showInterview = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "person.fill.questionmark")
                            .foregroundStyle(questionStore.questions.isEmpty ? Color.secondary : Color.teal)
                        if questionStore.newCount > 0 {
                            Text("\(questionStore.newCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(3)
                                .background(Color.orange, in: Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                }
                Button {
                    showCompanyPrep = true
                } label: {
                    Image(systemName: "building.2")
                        .foregroundStyle(Color.secondary)
                }
                Button {
                    showChallenges = true
                } label: {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(Color.secondary)
                }
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Color.secondary)
                }
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
