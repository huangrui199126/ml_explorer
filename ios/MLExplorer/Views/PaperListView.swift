import SwiftUI

struct PaperListView: View {
    @StateObject private var vm = PapersViewModel()
    @State private var showFilters = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.papers.isEmpty {
                    ProgressView("Loading papers…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage, vm.papers.isEmpty {
                    ContentUnavailableView {
                        Label("Failed to load", systemImage: "wifi.slash")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") { Task { await vm.load() } }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    paperList
                }
            }
            .navigationTitle("ML Explorer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .searchable(text: $vm.searchText, prompt: "Search papers, authors…")
        }
        .task { await vm.load() }
        .sheet(isPresented: $showFilters) {
            FilterSheetView(vm: vm)
        }
    }

    private var paperList: some View {
        List(vm.filteredPapers) { paper in
            NavigationLink(destination: PaperDetailView(paper: paper)) {
                PaperCardView(paper: paper)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
        .listStyle(.plain)
        .overlay(alignment: .top) {
            if vm.isLoading && !vm.papers.isEmpty {
                ProgressView()
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 4)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            statsBar
        }
    }

    private var statsBar: some View {
        HStack {
            Text(vm.statsText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if vm.selectedTopic != "All" || vm.selectedCompany != "All" {
                Button("Clear filters") { vm.resetFilters() }
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showFilters = true
            } label: {
                Image(systemName: filterIcon)
                    .symbolVariant(hasActiveFilters ? .fill : .none)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: $vm.sortBy) {
                    ForEach(PapersViewModel.SortOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
        }
    }

    private var filterIcon: String { "line.3.horizontal.decrease.circle" }
    private var hasActiveFilters: Bool {
        vm.selectedTopic != "All" || vm.selectedCompany != "All"
    }
}
