//
//  BookmarksListView.swift
//  Scout
//

import SwiftUI

struct BookmarksListView: View {
    @Bindable var bookmarkManager: BookmarkManager
    let onSelect: (Bookmark) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeSettings) private var themeSettings

    var body: some View {
        NavigationStack {
            Group {
                if bookmarkManager.bookmarks.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Add bookmarks from the menu while browsing")
                    )
                } else {
                    List {
                        ForEach(bookmarkManager.bookmarks) { bookmark in
                            Button {
                                onSelect(bookmark)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.title)
                                        .font(.system(.body, design: themeSettings.fontDesign.fontDesign))
                                        .foregroundStyle(themeSettings.textColor)
                                        .lineLimit(2)

                                    Text(bookmark.url)
                                        .font(.system(.caption, design: themeSettings.fontDesign.fontDesign))
                                        .foregroundStyle(themeSettings.textColor.opacity(0.7))
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { offsets in
                            bookmarkManager.removeBookmarks(at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !bookmarkManager.bookmarks.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        EditButton()
                    }
                }
            }
        }
    }
}
