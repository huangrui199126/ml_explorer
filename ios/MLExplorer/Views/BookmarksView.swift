import SwiftUI

struct BookmarksView: View {
    @ObservedObject var vm: PapersViewModel
    @EnvironmentObject var bookmarks: BookmarkStore
    @Environment(\.dismiss) private var dismiss

    private var bookmarkedPapers: [Paper] {
        vm.papers.filter { bookmarks.isBookmarked($0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if bookmarkedPapers.isEmpty {
                    ContentUnavailableView {
                        Label("No Bookmarks", systemImage: "bookmark")
                    } description: {
                        Text("Tap the bookmark icon on any paper to save it here.")
                    }
                } else {
                    List(bookmarkedPapers) { paper in
                        NavigationLink(destination: PaperDetailView(paper: paper).environmentObject(bookmarks)) {
                            PaperCardView(paper: paper)
                                .environmentObject(bookmarks)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
