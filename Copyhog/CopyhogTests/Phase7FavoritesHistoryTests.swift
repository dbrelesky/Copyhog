import XCTest
import AppKit
@testable import Copyhog

// MARK: - ImageStore NSCache Tests

final class ImageStoreCacheTests: XCTestCase {

    func testLoadImageCachesResult() {
        let imageStore = ImageStore()
        let id = UUID()

        // Create and save a test image
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.green.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let paths = imageStore.saveImage(tiffData, id: id) else {
            XCTFail("Setup: image save failed")
            return
        }

        // First load — from disk, then cached
        let loaded1 = imageStore.loadImage(relativePath: paths.filePath)
        XCTAssertNotNil(loaded1, "First load should succeed from disk")

        // Second load — should come from cache (same result)
        let loaded2 = imageStore.loadImage(relativePath: paths.filePath)
        XCTAssertNotNil(loaded2, "Second load should succeed from cache")

        // Cleanup
        imageStore.deleteImage(relativePath: paths.filePath)
        imageStore.deleteImage(relativePath: paths.thumbnailPath)
    }

    func testInvalidateCacheRemovesCachedImage() {
        let imageStore = ImageStore()
        let id = UUID()

        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let paths = imageStore.saveImage(tiffData, id: id) else {
            XCTFail("Setup: image save failed")
            return
        }

        // Load to populate cache
        _ = imageStore.loadImage(relativePath: paths.filePath)

        // Invalidate cache
        imageStore.invalidateCache(relativePath: paths.filePath)

        // Delete file on disk
        let url = imageStore.resolveURL(relativePath: paths.filePath)
        try? FileManager.default.removeItem(at: url)

        // Load again — cache is invalidated and file is gone, should return nil
        let loaded = imageStore.loadImage(relativePath: paths.filePath)
        XCTAssertNil(loaded, "After cache invalidation and file deletion, load should return nil")

        // Cleanup
        imageStore.deleteImage(relativePath: paths.thumbnailPath)
    }

    func testDeleteImageInvalidatesCache() {
        let imageStore = ImageStore()
        let id = UUID()

        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let paths = imageStore.saveImage(tiffData, id: id) else {
            XCTFail("Setup: image save failed")
            return
        }

        // Load to populate cache
        _ = imageStore.loadImage(relativePath: paths.filePath)

        // Delete (should invalidate cache AND remove file)
        imageStore.deleteImage(relativePath: paths.filePath)

        // Verify file is gone
        let loaded = imageStore.loadImage(relativePath: paths.filePath)
        XCTAssertNil(loaded, "After deleteImage, load should return nil (file and cache gone)")

        // Cleanup thumbnail
        imageStore.deleteImage(relativePath: paths.thumbnailPath)
    }

    func testInvalidateNonexistentCacheIsNoOp() {
        let imageStore = ImageStore()
        // Should not crash
        imageStore.invalidateCache(relativePath: "nonexistent.png")
    }
}

// MARK: - Settings History Limit Tests

@MainActor
final class HistoryLimitTests: XCTestCase {

    private func makeTextItem(_ text: String) -> ClipItem {
        ClipItem(
            id: UUID(), type: .text, content: text,
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )
    }

    private func makeCleanStore() -> ClipItemStore {
        let store = ClipItemStore()
        store.removeAll()
        return store
    }

    func testHistoryLimitIsPositive() {
        let store = makeCleanStore()
        XCTAssertGreaterThan(store.maxItems, 0, "History limit should be a positive number")
        XCTAssertLessThanOrEqual(store.maxItems, 500, "History limit should not exceed 500")
        store.removeAll()
    }

    func testStoreCapsAtMaxItems() {
        let store = makeCleanStore()
        let limit = store.maxItems

        for i in 0..<(limit + 5) {
            store.add(makeTextItem("item \(i)"))
        }

        XCTAssertEqual(store.items.count, limit,
                       "Store should cap at maxItems (\(limit))")
        store.removeAll()
    }
}
