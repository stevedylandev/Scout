//
//  SettingsView.swift
//  Scout
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var themeSettings: ThemeSettings
    @Environment(\.dismiss) private var dismiss
    var clientCertificateManager: ClientCertificateManager

    @State private var homePageText: String = ""
    @State private var searchEngineText: String = ""
    @State private var selectedAppearanceMode: AppearanceMode = .automatic
    @State private var selectedAccentColor: Color = .blue
    @State private var selectedLightBackgroundColor: Color = .white
    @State private var selectedLightTextColor: Color = .black
    @State private var selectedDarkBackgroundColor: Color = .black
    @State private var selectedDarkTextColor: Color = .white
    @State private var selectedFontDesign: FontDesignOption = .monospaced

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Home Page URL", text: $homePageText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                } header: {
                    Text("Home Page")
                } footer: {
                    Text("The page that loads when you open the app or tap the Home button.")
                }

                Section {
                    TextField("Search Engine URL", text: $searchEngineText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                } header: {
                    Text("Search Engine")
                } footer: {
                    Text("The search engine used when typing a search query. Your query will be appended after a \"?\".")
                }

                Section {
                    Picker("Appearance", selection: $selectedAppearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                } header: {
                    Text("Theme")
                } footer: {
                    Text("Choose between light, dark, or automatic appearance.")
                }

                Section {
                    ColorPicker("Accent Color", selection: $selectedAccentColor, supportsOpacity: false)
                    Picker("Font", selection: $selectedFontDesign) {
                        ForEach(FontDesignOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } header: {
                    Text("General")
                }

                Section {
                    ColorPicker("Background", selection: $selectedLightBackgroundColor, supportsOpacity: false)
                    ColorPicker("Text", selection: $selectedLightTextColor, supportsOpacity: false)
                } header: {
                    Text("Light Mode Colors")
                }

                Section {
                    ColorPicker("Background", selection: $selectedDarkBackgroundColor, supportsOpacity: false)
                    ColorPicker("Text", selection: $selectedDarkTextColor, supportsOpacity: false)
                } header: {
                    Text("Dark Mode Colors")
                }

                Section {
                    NavigationLink {
                        ClientCertificatesView(manager: clientCertificateManager)
                    } label: {
                        HStack {
                            Label("Client Certificates", systemImage: "person.badge.key")
                            Spacer()
                            Text("\(clientCertificateManager.certificates.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text("Manage certificates for authenticating with Gemini capsules.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        themeSettings.homePage = homePageText
                        themeSettings.searchEngine = searchEngineText
                        themeSettings.setAppearanceMode(selectedAppearanceMode)
                        themeSettings.setAllAccentColors(selectedAccentColor)
                        themeSettings.setLightBackgroundColor(selectedLightBackgroundColor)
                        themeSettings.setLightTextColor(selectedLightTextColor)
                        themeSettings.setDarkBackgroundColor(selectedDarkBackgroundColor)
                        themeSettings.setDarkTextColor(selectedDarkTextColor)
                        themeSettings.setFontDesign(selectedFontDesign)
                        dismiss()
                    }
                }
            }
            .onAppear {
                homePageText = themeSettings.homePage
                searchEngineText = themeSettings.searchEngine
                selectedAppearanceMode = themeSettings.appearanceMode
                selectedAccentColor = themeSettings.accentColor
                selectedLightBackgroundColor = themeSettings.lightBackgroundColor
                selectedLightTextColor = themeSettings.lightTextColor
                selectedDarkBackgroundColor = themeSettings.darkBackgroundColor
                selectedDarkTextColor = themeSettings.darkTextColor
                selectedFontDesign = themeSettings.fontDesign
            }
        }
    }
}

#Preview {
    SettingsView(clientCertificateManager: ClientCertificateManager())
        .environmentObject(ThemeSettings())
}
