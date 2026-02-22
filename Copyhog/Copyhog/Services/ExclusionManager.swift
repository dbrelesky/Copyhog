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

    /// The bundle ID of the most recently active app, tracked via workspace notifications.
    private(set) var lastActiveBundleID: String?

    /// Timestamp of when an excluded app was last in the foreground.
    /// Used for time-window detection — if an excluded app was active
    /// within the last few seconds, we assume the clipboard change came from it.
    private var lastExcludedAppTimestamp: Date?

    /// How many seconds after leaving an excluded app we still block captures.
    /// With 100ms polling, a shorter window is sufficient while reducing false positives.
    private static let exclusionWindowSeconds: TimeInterval = 1.5

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

        lastActiveBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let id = lastActiveBundleID, excludedBundleIDs.contains(id) {
            lastExcludedAppTimestamp = Date()
        }
        startTrackingActiveApp()
    }

    // MARK: - Public API

    /// Returns true if the clipboard change should be blocked.
    /// Checks: current frontmost app, last tracked app, AND time-window.
    func shouldBlockCapture() -> Bool {
        // 1. Check currently frontmost app
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           excludedBundleIDs.contains(bundleID) {
            return true
        }

        // 2. Check last tracked active app
        if let bundleID = lastActiveBundleID, excludedBundleIDs.contains(bundleID) {
            return true
        }

        // 3. Time-window: was an excluded app active in the last N seconds?
        if let timestamp = lastExcludedAppTimestamp,
           Date().timeIntervalSince(timestamp) < Self.exclusionWindowSeconds {
            return true
        }

        return false
    }

    /// Legacy method — now delegates to shouldBlockCapture().
    func isExcluded() -> Bool {
        shouldBlockCapture()
    }

    func isExcluded(bundleID: String) -> Bool {
        excludedBundleIDs.contains(bundleID)
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

    private func startTrackingActiveApp() {
        // Track when an app gains focus
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            MainActor.assumeIsolated {
                self?.lastActiveBundleID = bundleID
                if self?.excludedBundleIDs.contains(bundleID) == true {
                    self?.lastExcludedAppTimestamp = Date()
                }
            }
        }

        // Track when an app loses focus — this fires with the LEAVING app's
        // bundle ID, so we reliably catch when the user leaves Dashlane/1Password
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            MainActor.assumeIsolated {
                if self?.excludedBundleIDs.contains(bundleID) == true {
                    self?.lastExcludedAppTimestamp = Date()
                }
            }
        }
    }
}
