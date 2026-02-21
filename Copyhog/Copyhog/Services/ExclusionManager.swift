import AppKit
import Foundation

@MainActor
final class ExclusionManager: ObservableObject {

    struct KnownApp: Identifiable {
        let id: String // bundleID
        let name: String
    }

    static let knownApps: [KnownApp] = [
        KnownApp(id: "com.1password.1password", name: "1Password"),
        KnownApp(id: "com.apple.keychainaccess", name: "Keychain Access"),
        KnownApp(id: "com.apple.Terminal", name: "Terminal"),
        KnownApp(id: "com.googlecode.iterm2", name: "iTerm2"),
        KnownApp(id: "com.dashlane.Dashlane", name: "Dashlane"),
    ]

    @Published var excludedBundleIDs: Set<String> {
        didSet { persist() }
    }

    private static let defaultExclusions: Set<String> = [
        "com.1password.1password",
        "com.apple.keychainaccess",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.dashlane.Dashlane",
    ]

    private static let userDefaultsKey = "excludedBundleIDs"

    init() {
        if let saved = UserDefaults.standard.stringArray(forKey: Self.userDefaultsKey) {
            excludedBundleIDs = Set(saved)
        } else {
            excludedBundleIDs = Self.defaultExclusions
            persist()
        }
    }

    // MARK: - Public API

    func isExcluded() -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return excludedBundleIDs.contains(bundleID)
    }

    func addExclusion(_ bundleID: String) {
        excludedBundleIDs.insert(bundleID)
    }

    func removeExclusion(_ bundleID: String) {
        excludedBundleIDs.remove(bundleID)
    }

    // MARK: - Private

    private func persist() {
        UserDefaults.standard.set(Array(excludedBundleIDs), forKey: Self.userDefaultsKey)
    }
}
