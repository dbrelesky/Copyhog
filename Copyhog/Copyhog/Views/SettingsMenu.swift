import SwiftUI
import ServiceManagement

struct SettingsMenu: View {
    @Binding var showWipeConfirmation: Bool
    @EnvironmentObject var exclusionManager: ExclusionManager
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("historyLimit") private var historyLimit = 20

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        Menu {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    if newValue {
                        try? SMAppService.mainApp.register()
                    } else {
                        try? SMAppService.mainApp.unregister()
                    }
                }

            historySizePicker

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

            Text("Copyhog v\(appVersion) by DeeB")
        } label: {
            Image(systemName: "gearshape")
                .fontWeight(.medium)
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - History Size Picker

    private var historySizePicker: some View {
        Picker("History Size", selection: $historyLimit) {
            Text("10").tag(10)
            Text("20").tag(20)
            Text("30").tag(30)
            Text("40").tag(40)
            Text("50").tag(50)
        }
    }

    // MARK: - Excluded Apps Submenu

    private var excludedAppsSubmenu: some View {
        Menu("Excluded Apps") {
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
                Label("Exclude Current App", systemImage: "plus.circle")
            }
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
}
