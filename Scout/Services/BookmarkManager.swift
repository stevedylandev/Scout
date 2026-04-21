//
//  BookmarkManager.swift
//  Scout
//

import Foundation
import SwiftUI

struct Bookmark: Identifiable, Codable, Equatable {
    let id: UUID
    let url: String
    let title: String
    let dateAdded: Date

    init(id: UUID = UUID(), url: String, title: String, dateAdded: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.dateAdded = dateAdded
    }
}

@Observable
class BookmarkManager {
    private let storageKey = "titan_bookmarks"

    var bookmarks: [Bookmark] = []

    init() {
        loadBookmarks()
    }

    func addBookmark(url: String, title: String) {
        // Don't add duplicate URLs
        guard !bookmarks.contains(where: { $0.url == url }) else { return }

        let bookmark = Bookmark(url: url, title: title)
        bookmarks.insert(bookmark, at: 0)
        saveBookmarks()
    }

    func removeBookmark(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks()
    }

    func removeBookmarks(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        saveBookmarks()
    }

    func isBookmarked(url: String) -> Bool {
        bookmarks.contains { $0.url == url }
    }

    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) else {
            return
        }
        bookmarks = decoded
    }
}
