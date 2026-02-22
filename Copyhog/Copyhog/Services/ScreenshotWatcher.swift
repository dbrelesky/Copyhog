import AppKit
import Foundation

@MainActor
final class ScreenshotWatcher {

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var knownFiles: Set<String> = []
    private let bookmarkManager: BookmarkManager

    init(bookmarkManager: BookmarkManager) {
        self.bookmarkManager = bookmarkManager
    }

    // MARK: - Public API

    func start(
        clipboardObserver: ClipboardObserver,
        imageStore: ImageStore,
        onNewItem: @escaping (ClipItem) -> Void
    ) {
        guard let screenshotDir = bookmarkManager.startAccessing(key: BookmarkManager.screenshotSourceKey) else {
            print("[ScreenshotWatcher] No screenshot source bookmark — screenshot capture disabled")
            return
        }
        guard let screeniesDir = bookmarkManager.startAccessing(key: BookmarkManager.screeniesDestKey) else {
            print("[ScreenshotWatcher] No screenies dest bookmark — screenshot capture disabled")
            bookmarkManager.stopAccessing(key: BookmarkManager.screenshotSourceKey)
            return
        }

        // Ensure Screenies directory exists
        try? FileManager.default.createDirectory(
            at: screeniesDir,
            withIntermediateDirectories: true
        )

        // Snapshot existing files so we only react to NEW screenshots
        if let files = try? FileManager.default.contentsOfDirectory(atPath: screenshotDir.path) {
            knownFiles = Set(files.filter { $0.hasSuffix(".png") || $0.hasSuffix(".jpg") || $0.hasSuffix(".jpeg") })
        }

        // Open directory for monitoring
        fileDescriptor = open(screenshotDir.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("[ScreenshotWatcher] Failed to open screenshot directory")
            return
        }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: .main
        )

        source?.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                // Wait 0.5s for the screenshot file to finish writing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    MainActor.assumeIsolated {
                        self?.handleDirectoryChange(
                            screenshotDir: screenshotDir,
                            screeniesDir: screeniesDir,
                            clipboardObserver: clipboardObserver,
                            imageStore: imageStore,
                            onNewItem: onNewItem
                        )
                    }
                }
            }
        }

        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }

        source?.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
        bookmarkManager.stopAccessing(key: BookmarkManager.screenshotSourceKey)
        bookmarkManager.stopAccessing(key: BookmarkManager.screeniesDestKey)
    }

    // MARK: - Private

    private func handleDirectoryChange(
        screenshotDir: URL,
        screeniesDir: URL,
        clipboardObserver: ClipboardObserver,
        imageStore: ImageStore,
        onNewItem: @escaping (ClipItem) -> Void
    ) {
        guard let allFiles = try? FileManager.default.contentsOfDirectory(atPath: screenshotDir.path) else {
            return
        }

        let imageFiles = allFiles.filter { $0.hasSuffix(".png") || $0.hasSuffix(".jpg") || $0.hasSuffix(".jpeg") }
        let newFiles = imageFiles.filter { !knownFiles.contains($0) }

        for fileName in newFiles {
            // Verify it looks like a macOS screenshot
            guard isScreenshot(fileName: fileName) else {
                knownFiles.insert(fileName)
                continue
            }

            let sourceURL = screenshotDir.appendingPathComponent(fileName)

            // Verify file size is stable (file finished writing)
            guard isFileStable(at: sourceURL) else {
                // Don't add to knownFiles yet — we'll catch it on next event
                continue
            }

            let destURL = screeniesDir.appendingPathComponent(fileName)

            do {
                // Move to Screenies folder
                try FileManager.default.moveItem(at: sourceURL, to: destURL)

                // Read image data from new location
                let imageData = try Data(contentsOf: destURL)

                // Save to ImageStore for the item store
                let id = UUID()
                guard let paths = imageStore.saveImage(imageData, id: id) else {
                    knownFiles.insert(fileName)
                    continue
                }

                // Copy to system clipboard (with loop prevention)
                if let nsImage = NSImage(data: imageData) {
                    clipboardObserver.skipNextChange()
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([nsImage])
                    clipboardObserver.finishOwnWrite()
                }

                // Create ClipItem and notify
                let item = ClipItem(
                    id: id,
                    type: .image,
                    content: nil,
                    thumbnailPath: paths.thumbnailPath,
                    filePath: paths.filePath,
                    timestamp: Date(),
                    sourceAppBundleID: "com.apple.screencaptureui",
                    sourceAppName: "Screenshot"
                )
                onNewItem(item)

            } catch {
                print("[ScreenshotWatcher] Failed to process screenshot \(fileName): \(error)")
            }

            knownFiles.insert(fileName)
        }
    }

    private func isScreenshot(fileName: String) -> Bool {
        // macOS screenshots match pattern: "Screenshot YYYY-MM-DD at HH.MM.SS"
        // or localized variants. Check for common prefix.
        let lower = fileName.lowercased()
        return lower.hasPrefix("screenshot") || lower.hasPrefix("screen shot")
    }

    private func isFileStable(at url: URL) -> Bool {
        guard let attrs1 = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size1 = attrs1[.size] as? UInt64 else {
            return false
        }
        // Brief wait
        Thread.sleep(forTimeInterval: 0.2)
        guard let attrs2 = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size2 = attrs2[.size] as? UInt64 else {
            return false
        }
        return size1 == size2 && size1 > 0
    }
}
