//
//  TabManager.swift
//  Scout
//

import Foundation

@Observable
class TabManager {
    private let storageKey = "titan_tabs"
    private let activeTabKey = "titan_active_tab"

    var tabs: [Tab] = []
    var activeTabId: UUID?

    var activeTab: Tab? {
        get { tabs.first { $0.id == activeTabId } }
        set {
            if let newValue = newValue,
               let index = tabs.firstIndex(where: { $0.id == newValue.id }) {
                tabs[index] = newValue
                save()
            }
        }
    }

    var activeTabIndex: Int? {
        tabs.firstIndex { $0.id == activeTabId }
    }

    init() {
        load()
        if tabs.isEmpty {
            createTab()
        }
    }

    @discardableResult
    func createTab(url: String = "") -> Tab {
        let tab = Tab(url: url)
        tabs.append(tab)
        activeTabId = tab.id
        save()
        return tab
    }

    func closeTab(id: UUID?) {
        guard let id = id else { return }
        guard tabs.count > 1 else { return }

        let closingIndex = tabs.firstIndex { $0.id == id }
        tabs.removeAll { $0.id == id }

        if activeTabId == id {
            if let closingIndex = closingIndex {
                let newIndex = min(closingIndex, tabs.count - 1)
                activeTabId = tabs[newIndex].id
            } else {
                activeTabId = tabs.first?.id
            }
        }
        save()
    }

    func switchTo(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabId = id
        save()
    }

    func updateActiveTab(url: String? = nil, title: String? = nil, responseText: String? = nil, history: [String]? = nil, historyIndex: Int? = nil) {
        guard var tab = activeTab else { return }

        if let url = url { tab.url = url }
        if let title = title { tab.title = title }
        if let responseText = responseText { tab.responseText = responseText }
        if let history = history { tab.history = history }
        if let historyIndex = historyIndex { tab.historyIndex = historyIndex }

        activeTab = tab
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tabs) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        if let activeId = activeTabId {
            UserDefaults.standard.set(activeId.uuidString, forKey: activeTabKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Tab].self, from: data) {
            tabs = decoded
        }

        if let activeIdString = UserDefaults.standard.string(forKey: activeTabKey),
           let activeId = UUID(uuidString: activeIdString),
           tabs.contains(where: { $0.id == activeId }) {
            activeTabId = activeId
        } else {
            activeTabId = tabs.first?.id
        }
    }
}
