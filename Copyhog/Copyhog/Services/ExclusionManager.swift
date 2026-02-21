import AppKit
import Foundation

@MainActor
final class ExclusionManager: ObservableObject {

    @Published var excludedBundleIDs: Set<String> {
        didSet { persist() }
    }

    private static let defaultExclusions: Set<String> = [
        "com.1password.1password",
        "com.apple.keychainaccess",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
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
