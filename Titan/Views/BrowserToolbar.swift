//
//  BrowserToolbar.swift
//  Titan
//

import SwiftUI

struct BrowserToolbar: View {
    @EnvironmentObject private var themeSettings: ThemeSettings

    // State bindings
    @Binding var urlText: String
    var isURLFocused: FocusState<Bool>.Binding
    let isLoading: Bool
    let canGoBack: Bool
    let canGoForward: Bool
    let tabCount: Int
    let isBookmarked: Bool
    let canCloseTab: Bool

    // Callbacks
    let onBack: () -> Void
    let onForward: () -> Void
    let onSubmitURL: () -> Void
    let onCancel: () -> Void
    let onDismissKeyboard: () -> Void
    let onShowTabs: () -> Void
    let onNewTab: () -> Void
    let onCloseTab: () -> Void
    let onShowSettings: () -> Void
    let onShowBookmarks: () -> Void
    let onAddBookmark: () -> Void
    let onShowHistory: () -> Void
    let onGoHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                IndeterminateProgressBar(color: themeSettings.progressBarColor)
            } else {
                Color.clear
                    .frame(height: 3)
            }

            GlassEffectContainer {
                HStack(spacing: 12) {
                    // Navigation buttons in a single pill
                    if !isURLFocused.wrappedValue {
                        navigationButtons
                    }

                    urlTextField

                    if isURLFocused.wrappedValue {
                        dismissButton
                    } else {
                        menuButton
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: isURLFocused.wrappedValue)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Subviews

    private var navigationButtons: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundStyle(canGoBack && !isLoading ? themeSettings.toolbarButtonColor : themeSettings.toolbarButtonColor.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoBack || isLoading)

            Divider()
                .frame(height: 24)

            Button(action: onForward) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundStyle(canGoForward && !isLoading ? themeSettings.toolbarButtonColor : themeSettings.toolbarButtonColor.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoForward || isLoading)
        }
        .glassEffect(.regular.interactive())
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    private var urlTextField: some View {
        HStack(spacing: 0) {
            TextField("gemini:// or search", text: $urlText)
                .focused(isURLFocused)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .onSubmit {
                    isURLFocused.wrappedValue = false
                    onSubmitURL()
                }
                .padding(.leading, 12)
                .padding(.vertical, 12)

            if isLoading {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(themeSettings.toolbarButtonColor.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else if isURLFocused.wrappedValue && !urlText.isEmpty {
                Button {
                    urlText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(themeSettings.toolbarButtonColor.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else {
                Spacer()
                    .frame(width: 12)
            }
        }
        .glassEffect(.regular, in: .capsule)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: isURLFocused.wrappedValue)
        .animation(.easeInOut(duration: 0.2), value: urlText.isEmpty)
    }

    private var dismissButton: some View {
        Button {
            isURLFocused.wrappedValue = false
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(themeSettings.toolbarButtonColor)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive())
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    private var menuButton: some View {
        Menu {
            // New Tab
            Button {
                onNewTab()
            } label: {
                Label("New Tab", systemImage: "plus")
            }
            
            // Add to Bookmarks
            Button {
                onAddBookmark()
            } label: {
                if isBookmarked {
                    Label("Bookmarked", systemImage: "bookmark.fill")
                } else {
                    Label("Add to Bookmarks", systemImage: "bookmark")
                }
            }
            .disabled(urlText.isEmpty || isBookmarked)

            Divider()

            // History
            Button {
                onShowHistory()
            } label: {
                Label("History", systemImage: "clock")
            }

            // Settings
            Button {
                onShowSettings()
            } label: {
                Label("Settings", systemImage: "gear")
            }

            Divider()

            // Bottom section: Bookmarks | Tabs as large square buttons with labels
            ControlGroup {
                Button {
                    onShowBookmarks()
                } label: {
                    Label("Bookmarks", systemImage: "book")
                }

                Button {
                    onShowTabs()
                } label: {
                    Label("All Tabs", systemImage: "square.on.square")
                }
            }
            .controlGroupStyle(.menu)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
                .foregroundStyle(themeSettings.toolbarButtonColor)
                .frame(width: 44, height: 44)
        }
        .menuOrder(.fixed)
        .glassEffect(.regular.interactive())
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }
}
