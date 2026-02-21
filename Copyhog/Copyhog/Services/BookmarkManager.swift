import Foundation

@MainActor
final class BookmarkManager {

    static let screenshotSourceKey = "bookmark.screenshotSource"
    static let screeniesDestKey = "bookmark.screeniesDest"

    private var activeURLs: [String: URL] = [:]

    // MARK: - Save & Resolve

    func saveBookmark(url: URL, key: String) {
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("[BookmarkManager] Failed to save bookmark for \(key): \(error)")
        }
    }

    func resolveBookmark(key: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                saveBookmark(url: url, key: key)
            }
            return url
        } catch {
            print("[BookmarkManager] Failed to resolve bookmark for \(key): \(error)")
            return nil
        }
    }

    // MARK: - Access Control

    func startAccessing(key: String) -> URL? {
        if let existing = activeURLs[key] { return existing }
        guard let url = resolveBookmark(key: key) else { return nil }
        guard url.startAccessingSecurityScopedResource() else {
            print("[BookmarkManager] startAccessingSecurityScopedResource failed for \(key)")
            return nil
        }
        activeURLs[key] = url
        return url
    }

    func stopAccessing(key: String) {
        guard let url = activeURLs.removeValue(forKey: key) else { return }
        url.stopAccessingSecurityScopedResource()
    }

    func stopAccessingAll() {
        for (_, url) in activeURLs {
            url.stopAccessingSecurityScopedResource()
        }
        activeURLs.removeAll()
    }

    // MARK: - Query

    func hasBookmark(key: String) -> Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }

    var hasCompletedSetup: Bool {
        hasBookmark(key: Self.screenshotSourceKey) && hasBookmark(key: Self.screeniesDestKey)
    }
}
