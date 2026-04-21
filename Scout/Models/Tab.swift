//
//  Tab.swift
//  Scout
//

import Foundation

struct Tab: Identifiable, Codable, Equatable {
    let id: UUID
    var url: String
    var title: String
    var responseText: String
    var history: [String]
    var historyIndex: Int

    init(id: UUID = UUID(), url: String = "", title: String = "", responseText: String = "", history: [String] = [], historyIndex: Int = -1) {
        self.id = id
        self.url = url
        self.title = title
        self.responseText = responseText
        self.history = history
        self.historyIndex = historyIndex
    }
}
