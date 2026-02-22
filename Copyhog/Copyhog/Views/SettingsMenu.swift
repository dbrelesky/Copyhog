import SwiftUI
import ServiceManagement

struct SettingsMenu: View {
    @Binding var showWipeConfirmation: Bool
    @EnvironmentObject var exclusionManager: ExclusionManager
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("historyLimit") private var historyLimit = 20
    @AppStorage("plainPasteEnabled") private var plainPasteEnabled = true
    @AppStorage("appearanceMode") private var appearanceMode = 0

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        Menu {
            Toggle(isOn: $launchAtLogin) {
                Label("Launch at Login", systemImage: "arrow.clockwise")
            }
                .onChange(of: launchAtLogin) { _, newValue in
                    if newValue {
                        try? SMAppService.mainApp.register()
                    } else {
                        try? SMAppService.mainApp.unregister()
                    }
                }

            historySizePicker

            Toggle(isOn: $plainPasteEnabled) {
                Label("Plain Paste (⇧⌘V)", systemImage: "doc.plaintext")
            }

            appearanceSubmenu

            Divider()

            excludedAppsSubmenu

            Button {
                setupScreenshotFolders()
            } label: {
                Label("Setup Screenshot Folders...", systemImage: "folder.badge.gearshape")
            }

            Divider()

            Button(role: .destructive) {
                showWipeConfirmation = true
            } label: {
                Label("Hog Wipe...", systemImage: "trash")
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Copyhog", systemImage: "xmark.circle")
            }

            Divider()

            Label("Open the Hog from anywhere with ⌃⌘C", systemImage: "lightbulb")


            Label("Copyhog v\(appVersion) by DeeB", image: "MenuBarIcon")
        } label: {
            Image(systemName: "gearshape")
                .fontWeight(.medium)
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - History Size Picker

    private var historySizePicker: some View {
        Picker(selection: $historyLimit) {
            Text("20").tag(20)
            Text("50").tag(50)
            Text("100").tag(100)
            Text("200").tag(200)
            Text("500").tag(500)
        } label: {
            Label("History Size", systemImage: "clock.arrow.circlepath")
        }
    }

    // MARK: - Shielded Apps Submenu

    private var excludedAppsSubmenu: some View {
        Menu {
            ForEach(ExclusionManager.knownApps) { app in
                let isExcluded = exclusionManager.excludedBundleIDs.contains(app.id)
                Button {
                    if isExcluded {
                        exclusionManager.removeExclusion(app.id)
                    } else {
                        exclusionManager.addExclusion(app.id)
                    }
                } label: {
                    HStack {
                        Text(app.name)
                        if isExcluded {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            let customExclusions = exclusionManager.excludedBundleIDs
                .filter { bundleID in !ExclusionManager.knownApps.contains(where: { $0.id == bundleID }) }
                .sorted()
            if !customExclusions.isEmpty {
                ForEach(customExclusions, id: \.self) { bundleID in
                    Button {
                        exclusionManager.removeExclusion(bundleID)
                    } label: {
                        Label(displayName(for: bundleID), systemImage: "xmark.circle")
                    }
                }

                Divider()
            }

            Button {
                excludeCurrentApp()
            } label: {
                Label("Shield Current App", systemImage: "plus.circle")
            }
        } label: {
            Label("Shielded Apps", systemImage: "shield.lefthalf.filled")
        }
    }

    private func excludeCurrentApp() {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return
        }
        exclusionManager.addExclusion(bundleID)
    }

    private func setupScreenshotFolders() {
        NotificationCenter.default.post(name: .showScreenshotSetup, object: nil)
    }

    private func displayName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let name = url.deletingPathExtension().lastPathComponent
            if !name.isEmpty { return name }
        }
        return bundleID
    }

    // MARK: - Appearance Submenu

    private var appearanceSubmenu: some View {
        Menu {
            Button {
                appearanceMode = 0
            } label: {
                HStack {
                    Label("System", systemImage: "circle.lefthalf.filled")
                    if appearanceMode == 0 { Image(systemName: "checkmark") }
                }
            }
            Button {
                appearanceMode = 1
            } label: {
                HStack {
                    Label("Light", systemImage: "sun.max")
                    if appearanceMode == 1 { Image(systemName: "checkmark") }
                }
            }
            Button {
                appearanceMode = 2
            } label: {
                HStack {
                    Label("Dark", systemImage: "moon")
                    if appearanceMode == 2 { Image(systemName: "checkmark") }
                }
            }
        } label: {
            Label("Appearance", systemImage: "paintbrush")
        }
    }
}
