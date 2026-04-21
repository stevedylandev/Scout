//
//  HistoryManager.swift
//  Scout
//

import Foundation
import SwiftUI

struct HistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let url: String
    let title: String
    let visitedAt: Date

    init(id: UUID = UUID(), url: String, title: String, visitedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.visitedAt = visitedAt
    }
}

@Observable
class HistoryManager {
    private let storageKey = "titan_history"

    var items: [HistoryItem] = []

    init() {
        loadHistory()
    }

    func addToHistory(url: String, title: String) {
        let item = HistoryItem(url: url, title: title)
        items.insert(item, at: 0)
        saveHistory()
    }

    func removeItem(_ item: HistoryItem) {
        items.removeAll { $0.id == item.id }
        saveHistory()
    }

    func removeItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        saveHistory()
    }

    func clearAll() {
        items.removeAll()
        saveHistory()
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
            return
        }
        items = decoded
    }
}
