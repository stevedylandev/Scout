//
//  HistoryListView.swift
//  Scout
//

import SwiftUI

struct HistoryListView: View {
    @Bindable var historyManager: HistoryManager
    let onSelect: (HistoryItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeSettings) private var themeSettings
    @State private var showClearConfirmation = false

    private var groupedHistory: [(String, [HistoryItem])] {
        let calendar = Calendar.current
        let now = Date()

        var groups: [String: [HistoryItem]] = [:]

        for item in historyManager.items {
            let key: String
            if calendar.isDateInToday(item.visitedAt) {
                key = "Today"
            } else if calendar.isDateInYesterday(item.visitedAt) {
                key = "Yesterday"
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                      item.visitedAt > weekAgo {
                key = "This Week"
            } else {
                key = "Older"
            }

            groups[key, default: []].append(item)
        }

        let order = ["Today", "Yesterday", "This Week", "Older"]
        return order.compactMap { key in
            guard let items = groups[key], !items.isEmpty else { return nil }
            return (key, items)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if historyManager.items.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock",
                        description: Text("Pages you visit will appear here")
                    )
                } else {
                    List {
                        ForEach(groupedHistory, id: \.0) { section, items in
                            Section(section) {
                                ForEach(items) { item in
                                    Button {
                                        onSelect(item)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.title)
                                                .font(.system(.body, design: themeSettings.fontDesign.fontDesign))
                                                .foregroundStyle(themeSettings.textColor)
                                                .lineLimit(2)

                                            HStack {
                                                Text(item.url)
                                                    .font(.system(.caption, design: themeSettings.fontDesign.fontDesign))
                                                    .foregroundStyle(themeSettings.textColor.opacity(0.7))
                                                    .lineLimit(1)

                                                Spacer()

                                                Text(item.visitedAt, style: .time)
                                                    .font(.system(.caption2, design: themeSettings.fontDesign.fontDesign))
                                                    .foregroundStyle(themeSettings.textColor.opacity(0.5))
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .onDelete { offsets in
                                    deleteItems(in: items, at: offsets)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !historyManager.items.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(role: .destructive) {
                                showClearConfirmation = true
                            } label: {
                                Label("Clear All History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear All History",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    historyManager.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all browsing history.")
            }
        }
    }

    private func deleteItems(in sectionItems: [HistoryItem], at offsets: IndexSet) {
        for offset in offsets {
            let item = sectionItems[offset]
            historyManager.removeItem(item)
        }
    }
}
