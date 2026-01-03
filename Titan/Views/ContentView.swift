//
//  ContentView.swift
//  Titan
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var themeSettings: ThemeSettings
    @Binding var pendingDeepLinkURL: URL?
    @State private var urlText = ""
    @State private var responseText = ""
    @State private var isLoading = false

    // Input prompt state
    @State private var showInputPrompt = false
    @State private var inputPromptText = ""
    @State private var inputValue = ""
    @State private var inputIsSensitive = false
    @State private var pendingInputURL = ""

    // Navigation history
    @State private var history: [String] = []
    @State private var historyIndex = -1

    // Media preview state
    @State private var showMediaPreview = false
    @State private var mediaContent: MediaContent?

    // Current fetch task (for cancellation)
    @State private var currentFetchTask: Task<Void, Never>?

    // Bookmarks
    @State private var bookmarkManager = BookmarkManager()
    @State private var showBookmarks = false

    // History
    @State private var historyManager = HistoryManager()
    @State private var showHistory = false

    // Settings
    @State private var showSettings = false

    // Tabs
    @State private var tabManager = TabManager()
    @State private var showTabs = false

    // URL input focus state
    @FocusState private var isURLFocused: Bool

    // Error state
    @State private var currentError: GeminiErrorType?

    // Certificate management
    @State private var certificateManager = CertificateManager()
    @State private var showCertificateMismatchAlert = false
    @State private var pendingCertificateChange: (hostname: String, storedFingerprint: String, newFingerprint: String, commonName: String)?
    @State private var pendingCertificateURL: String?

    private let maxRedirects = 5

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let error = currentError {
                    ErrorPageView(errorType: error, onRetry: {
                        navigateTo(urlText)
                    })
                    .id("top")
                } else {
                    TitanContentView(content: responseText, baseURL: urlText, onLinkTap: { url in
                        navigateTo(url)
                    })
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .id("top")
                }
            }
            .onChange(of: responseText) {
                withAnimation {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
            .contentMargins(.top, 20, for: .scrollContent)
            .background(themeSettings.backgroundColor)
            .safeAreaInset(edge: .bottom) {
                BrowserToolbar(
                    urlText: $urlText,
                    isURLFocused: $isURLFocused,
                    isLoading: isLoading,
                    canGoBack: canGoBack,
                    canGoForward: canGoForward,
                    tabCount: tabManager.tabs.count,
                    isBookmarked: bookmarkManager.isBookmarked(url: urlText),
                    canCloseTab: tabManager.tabs.count > 1,
                    onBack: goBack,
                    onForward: goForward,
                    onSubmitURL: { navigateTo(urlText) },
                    onCancel: cancelCurrentRequest,
                    onDismissKeyboard: { isURLFocused = false },
                    onShowTabs: { showTabs = true },
                    onNewTab: {
                        saveCurrentTabState()
                        tabManager.createTab(url: themeSettings.homePage)
                        loadActiveTabState()
                        navigateTo(themeSettings.homePage)
                    },
                    onCloseTab: {
                        tabManager.closeTab(id: tabManager.activeTabId)
                        loadActiveTabState()
                    },
                    onShowSettings: { showSettings = true },
                    onShowBookmarks: { showBookmarks = true },
                    onAddBookmark: addCurrentPageToBookmarks,
                    onShowHistory: { showHistory = true },
                    onGoHome: { navigateTo(themeSettings.homePage) }
                )
            }
        }
        .onAppear {
            loadActiveTabState()
            // If this is a fresh tab with no content, navigate to home
            if urlText.isEmpty {
                navigateTo(themeSettings.homePage)
            } else if responseText.isEmpty && !urlText.isEmpty {
                // Tab has URL but no content (restored from persistence)
                navigateTo(urlText)
            }
        }
        .onChange(of: pendingDeepLinkURL) { _, newURL in
            if let url = newURL {
                navigateTo(url.absoluteString)
                pendingDeepLinkURL = nil
            }
        }
        .alert("Input Required", isPresented: $showInputPrompt) {
            if inputIsSensitive {
                SecureField("Enter input", text: $inputValue)
            } else {
                TextField("Enter input", text: $inputValue)
            }
            Button("Cancel", role: .cancel) {
                inputValue = ""
            }
            Button("Submit") {
                submitInput()
            }
        } message: {
            Text(inputPromptText)
        }
        .fullScreenCover(isPresented: $showMediaPreview) {
            if let media = mediaContent {
                MediaPreviewView(media: media) {
                    showMediaPreview = false
                    mediaContent = nil
                }
            }
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksListView(bookmarkManager: bookmarkManager) { bookmark in
                showBookmarks = false
                navigateTo(bookmark.url)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showHistory) {
            HistoryListView(historyManager: historyManager) { item in
                showHistory = false
                navigateTo(item.url)
            }
        }
        .sheet(isPresented: $showTabs) {
            TabsListView(tabManager: tabManager) { tab in
                showTabs = false
                saveCurrentTabState()
                tabManager.switchTo(id: tab.id)
                loadActiveTabState()
                // If this is a new tab with no URL, navigate to home
                if urlText.isEmpty {
                    navigateTo(themeSettings.homePage)
                }
            }
        }
        .alert("Certificate Changed", isPresented: $showCertificateMismatchAlert) {
            Button("Reject", role: .cancel) {
                pendingCertificateChange = nil
                pendingCertificateURL = nil
            }
            Button("Accept New Certificate") {
                if let change = pendingCertificateChange {
                    certificateManager.updateCertificate(
                        hostname: change.hostname,
                        fingerprint: change.newFingerprint,
                        commonName: change.commonName
                    )
                    // Retry navigation with the updated certificate
                    if let url = pendingCertificateURL {
                        navigateTo(url)
                    }
                }
                pendingCertificateChange = nil
                pendingCertificateURL = nil
            }
        } message: {
            if let change = pendingCertificateChange {
                Text("The certificate for \(change.hostname) has changed.\n\nOld fingerprint:\n\(formatFingerprint(change.storedFingerprint))\n\nNew fingerprint:\n\(formatFingerprint(change.newFingerprint))\n\nThis could indicate a security issue or the server updated its certificate.")
            } else {
                Text("A certificate change was detected.")
            }
        }
    }

    private func formatFingerprint(_ fingerprint: String) -> String {
        fingerprint.prefix(32) + "..."
    }

    // MARK: - Tab State Management

    private func saveCurrentTabState() {
        let title = extractPageTitle() ?? urlText
        tabManager.updateActiveTab(
            url: urlText,
            title: title,
            responseText: responseText,
            history: history,
            historyIndex: historyIndex
        )
    }

    private func loadActiveTabState() {
        guard let tab = tabManager.activeTab else { return }
        urlText = tab.url
        responseText = tab.responseText
        history = tab.history
        historyIndex = tab.historyIndex
    }

    private func submitInput() {
        guard !inputValue.isEmpty else { return }

        let encoded = inputValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? inputValue
        let urlWithQuery = pendingInputURL + "?" + encoded
        inputValue = ""

        navigateTo(urlWithQuery)
    }

    // MARK: - Bookmarks

    private func addCurrentPageToBookmarks() {
        guard !urlText.isEmpty else { return }
        let title = extractPageTitle() ?? urlText
        bookmarkManager.addBookmark(url: urlText, title: title)
    }

    private func extractPageTitle() -> String? {
        let lines = GeminiParser.parse(responseText, baseURL: urlText)
        for line in lines {
            switch line {
            case .heading1(let text), .heading2(let text), .heading3(let text):
                return text
            default:
                continue
            }
        }
        return nil
    }

    // MARK: - Navigation History

    private var canGoBack: Bool {
        historyIndex > 0
    }

    private var canGoForward: Bool {
        historyIndex < history.count - 1
    }

    private func normalizeURL(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        // If it already has a scheme, return as-is
        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("gemini://") ||
           lowercased.hasPrefix("http://") ||
           lowercased.hasPrefix("https://") ||
           lowercased.hasPrefix("mailto:") {
            return trimmed
        }

        // Check if it looks like a domain (contains a dot, no spaces)
        if trimmed.contains(".") && !trimmed.contains(" ") {
            return "gemini://" + trimmed
        }

        // Otherwise treat as a search query
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return themeSettings.searchEngine + "?" + encoded
    }

    private func navigateTo(_ url: String) {
        let normalizedURL = normalizeURL(url)

        // Check if this is an external URL (http, https, mailto)
        if let urlObj = URL(string: normalizedURL) {
            let scheme = urlObj.scheme?.lowercased() ?? ""
            if scheme == "http" || scheme == "https" || scheme == "mailto" {
                UIApplication.shared.open(urlObj)
                return
            }
        }

        if historyIndex < history.count - 1 {
            history = Array(history.prefix(historyIndex + 1))
        }

        urlText = normalizedURL
        fetchContent(addToHistory: true)
    }

    private func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        urlText = history[historyIndex]
        fetchContent(addToHistory: false)
    }

    private func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        urlText = history[historyIndex]
        fetchContent(addToHistory: false)
    }

    private func cancelCurrentRequest() {
        currentFetchTask?.cancel()
        currentFetchTask = nil
        isLoading = false
    }

    private func addToNavigationHistory(url: String) {
        history.append(url)
        historyIndex = history.count - 1
        saveCurrentTabState()
    }

    private func fetchContent(addToHistory: Bool = true) {
        // Cancel any pending request before starting a new one
        currentFetchTask?.cancel()

        isLoading = true
        currentFetchTask = Task {
            do {
                let (response, finalURL) = try await fetchWithRedirects(urlString: urlText, redirectCount: 0)

                // Check if task was cancelled during fetch
                if Task.isCancelled { return }

                if finalURL != urlText {
                    urlText = finalURL
                }

                switch response.statusCategory {
                case .success:
                    currentError = nil
                    let mimeType = response.meta

                    if MediaType.isMediaContent(mimeType) {
                        // Handle media content (images, audio)
                        if let body = response.body {
                            mediaContent = MediaContent(
                                data: body,
                                mimeType: mimeType,
                                sourceURL: finalURL
                            )
                            showMediaPreview = true
                        } else {
                            responseText = "(empty media response)"
                        }
                    } else {
                        // Handle text content (text/gemini, text/plain, etc.)
                        responseText = response.bodyText ?? "(empty response)"
                        if addToHistory {
                            history.append(finalURL)
                            historyIndex = history.count - 1

                            // Add to persistent history
                            let title = extractPageTitle() ?? finalURL
                            historyManager.addToHistory(url: finalURL, title: title)
                        }
                        // Save tab state
                        saveCurrentTabState()
                    }
                case .input:
                    currentError = nil
                    pendingInputURL = finalURL
                    inputPromptText = response.meta
                    inputIsSensitive = response.statusCode == 11
                    showInputPrompt = true
                case .redirect:
                    currentError = .tooManyRedirects
                    if addToHistory {
                        addToNavigationHistory(url: finalURL)
                    }
                case .temporaryFailure:
                    currentError = .temporaryFailure(code: response.statusCode, meta: response.meta)
                    if addToHistory {
                        addToNavigationHistory(url: finalURL)
                    }
                case .permanentFailure:
                    currentError = .permanentFailure(code: response.statusCode, meta: response.meta)
                    if addToHistory {
                        addToNavigationHistory(url: finalURL)
                    }
                case .clientCertificate:
                    currentError = .clientCertificate(code: response.statusCode, meta: response.meta)
                    if addToHistory {
                        addToNavigationHistory(url: finalURL)
                    }
                }
                isLoading = false
            } catch is CancellationError {
                // Task was cancelled, don't update UI
                return
            } catch GeminiError.cancelled {
                // Request was cancelled, don't update UI
                return
            } catch let error as GeminiError {
                switch error {
                case .invalidResponse:
                    currentError = .invalidResponse
                case .invalidURL:
                    currentError = .invalidURL
                case .cancelled:
                    return
                case .certificateMismatch(let hostname, let storedFingerprint, let newFingerprint, let commonName):
                    pendingCertificateChange = (hostname, storedFingerprint, newFingerprint, commonName)
                    pendingCertificateURL = urlText
                    showCertificateMismatchAlert = true
                    isLoading = false
                    return
                case .certificateError:
                    currentError = .networkError("Could not verify server certificate")
                }
                if addToHistory {
                    addToNavigationHistory(url: urlText)
                }
                isLoading = false
            } catch {
                currentError = .networkError(error.localizedDescription)
                if addToHistory {
                    addToNavigationHistory(url: urlText)
                }
                isLoading = false
            }
        }
    }

    private func fetchWithRedirects(urlString: String, redirectCount: Int) async throws -> (GeminiResponse, String) {
        // Check for cancellation before starting
        try Task.checkCancellation()

        guard let url = URL(string: urlString),
              let host = url.host else {
            throw GeminiError.invalidURL
        }

        let client = GeminiClient(certificateManager: certificateManager)
        let port = url.port ?? 1965
        let response = try await client.connect(
            hostname: host,
            port: port,
            urlString: urlString
        )

        // Check for cancellation after fetch
        try Task.checkCancellation()

        if response.statusCategory == .redirect {
            guard redirectCount < maxRedirects else {
                return (response, urlString)
            }

            let redirectTarget: String
            if response.meta.hasPrefix("gemini://") {
                redirectTarget = response.meta
            } else {
                if let baseURL = URL(string: urlString),
                   let resolved = URL(string: response.meta, relativeTo: baseURL) {
                    redirectTarget = resolved.absoluteString
                } else {
                    redirectTarget = response.meta
                }
            }

            print("↪️ Redirecting to: \(redirectTarget)")
            return try await fetchWithRedirects(urlString: redirectTarget, redirectCount: redirectCount + 1)
        }

        return (response, urlString)
    }
}

#Preview {
    ContentView(pendingDeepLinkURL: .constant(nil))
        .environmentObject(ThemeSettings())
}
