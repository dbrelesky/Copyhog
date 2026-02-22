import AppKit
import Foundation

@MainActor
final class ClipboardObserver {

    private var timer: Timer?
    private var lastChangeCount: Int
    private let pasteboard = NSPasteboard.general
    private var isOwnWrite = false
    private let imageStore: ImageStore
    var exclusionManager: ExclusionManager?

    init(imageStore: ImageStore) {
        self.imageStore = imageStore
        self.lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Public API

    func start(onNewItem: @escaping (ClipItem) -> Void) {
        print("[ClipboardObserver] Starting clipboard polling (changeCount: \(lastChangeCount))")
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pollClipboard(onNewItem: onNewItem)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Called by ScreenshotWatcher before writing to the clipboard
    /// to prevent the observer from re-capturing its own write.
    func skipNextChange() {
        isOwnWrite = true
        // Immediately snapshot the current changeCount so that
        // when the external write bumps it, we skip that delta.
        lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Private

    private func pollClipboard(onNewItem: @escaping (ClipItem) -> Void) {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // If this change was triggered by us (ScreenshotWatcher), skip it
        if isOwnWrite {
            isOwnWrite = false
            print("[ClipboardObserver] Skipped own write")
            return
        }

        // Skip capture if the frontmost app is excluded
        if let em = exclusionManager, em.isExcluded() {
            let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
            print("[ClipboardObserver] Skipped — excluded app: \(bundleID)")
            return
        }

        // Check for text first
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            print("[ClipboardObserver] Captured text (\(string.prefix(40))...)")
            let item = ClipItem(
                id: UUID(),
                type: .text,
                content: string,
                thumbnailPath: nil,
                filePath: nil,
                timestamp: Date()
            )
            onNewItem(item)
            return
        }

        // Check for image (tiff or png)
        if let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            let id = UUID()
            if let paths = imageStore.saveImage(imageData, id: id) {
                let item = ClipItem(
                    id: id,
                    type: .image,
                    content: nil,
                    thumbnailPath: paths.thumbnailPath,
                    filePath: paths.filePath,
                    timestamp: Date()
                )
                onNewItem(item)
            }
        }
    }
}
