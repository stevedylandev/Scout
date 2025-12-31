//
//  TitanApp.swift
//  Titan
//
//  Created by Steve Simkins on 12/20/25.
//

import SwiftUI

@main
struct TitanApp: App {
    @StateObject private var themeSettings = ThemeSettings()
    @State private var pendingDeepLinkURL: URL?

    var body: some Scene {
        WindowGroup {
            ContentView(pendingDeepLinkURL: $pendingDeepLinkURL)
                .environment(\.themeSettings, themeSettings)
                .environmentObject(themeSettings)
                .preferredColorScheme(themeSettings.appearanceMode.colorScheme)
                .onOpenURL { url in
                    pendingDeepLinkURL = url
                }
        }
    }
}
