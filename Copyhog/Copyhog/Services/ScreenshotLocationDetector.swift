import Foundation

/// Detects where macOS saves screenshots by reading the system screencapture preference domain.
/// Requires entitlement: com.apple.security.temporary-exception.shared-preference.read-only
/// with value array containing "com.apple.screencapture".
struct ScreenshotLocationDetector {

    /// Detects the macOS screenshot save location.
    /// Returns the custom location if set and valid, otherwise ~/Desktop.
    static func detect() -> URL {
        if let location = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
           !location.isEmpty {
            let expanded = (location as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
    }
}
