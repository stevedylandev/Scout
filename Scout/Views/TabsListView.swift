//
//  TabsListView.swift
//  Scout
//

import SwiftUI

struct TabsListView: View {
    @Bindable var tabManager: TabManager
    let onSelect: (Tab) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeSettings) private var themeSettings

    var body: some View {
        NavigationStack {
            List {
                ForEach(tabManager.tabs) { tab in
                    Button {
                        onSelect(tab)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tab.title.isEmpty ? (tab.url.isEmpty ? "New Tab" : tab.url) : tab.title)
                                    .font(.system(.body, design: themeSettings.fontDesign.fontDesign))
                                    .foregroundStyle(themeSettings.textColor)
                                    .lineLimit(2)

                                if !tab.url.isEmpty && !tab.title.isEmpty {
                                    Text(tab.url)
                                        .font(.system(.caption, design: themeSettings.fontDesign.fontDesign))
                                        .foregroundStyle(themeSettings.textColor.opacity(0.7))
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 4)

                            Spacer()

                            if tab.id == tabManager.activeTabId {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        let tab = tabManager.tabs[index]
                        tabManager.closeTab(id: tab.id)
                    }
                }
            }
            .navigationTitle("Tabs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let newTab = tabManager.createTab()
                        onSelect(newTab)
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                if tabManager.tabs.count > 1 {
                    ToolbarItem(placement: .primaryAction) {
                        EditButton()
                    }
                }
            }
        }
    }
}
