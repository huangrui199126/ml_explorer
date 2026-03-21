import Foundation
import Combine

class BookmarkStore: ObservableObject {
    @Published private(set) var bookmarkedIDs: Set<String> = []

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: "ml_bookmarks") ?? []
        bookmarkedIDs = Set(saved)
    }

    func toggle(_ paper: Paper) {
        if bookmarkedIDs.contains(paper.id) {
            bookmarkedIDs.remove(paper.id)
        } else {
            bookmarkedIDs.insert(paper.id)
        }
        UserDefaults.standard.set(Array(bookmarkedIDs), forKey: "ml_bookmarks")
    }

    func isBookmarked(_ paper: Paper) -> Bool {
        bookmarkedIDs.contains(paper.id)
    }
}
