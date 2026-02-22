import XCTest
import AppKit
@testable import Copyhog

// MARK: - ClipItem isPinned Tests

final class ClipItemPinTests: XCTestCase {

    func testIsPinnedDefaultsToFalse() {
        let item = ClipItem(
            id: UUID(), type: .text, content: "test",
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )
        XCTAssertFalse(item.isPinned, "isPinned should default to false")
    }

    func testIsPinnedCanBeSetToTrue() {
        let item = ClipItem(
            id: UUID(), type: .text, content: "test",
            thumbnailPath: nil, filePath: nil, timestamp: Date(),
            isPinned: true
        )
        XCTAssertTrue(item.isPinned)
    }

    func testIsPinnedIsMutable() {
        var item = ClipItem(
            id: UUID(), type: .text, content: "test",
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )
        XCTAssertFalse(item.isPinned)
        item.isPinned = true
        XCTAssertTrue(item.isPinned, "isPinned should be mutable (var, not let)")
    }

    func testCodableRoundTripPreservesIsPinned() throws {
        let item = ClipItem(
            id: UUID(), type: .text, content: "pinned item",
            thumbnailPath: nil, filePath: nil, timestamp: Date(),
            isPinned: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ClipItem.self, from: data)

        XCTAssertEqual(decoded.isPinned, true, "isPinned should survive encode/decode round trip")
        XCTAssertEqual(decoded.id, item.id)
    }

    func testBackwardCompatibleDecodingWithoutIsPinned() throws {
        // Simulate old JSON without isPinned field
        let json = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "type": "text",
            "content": "old item",
            "timestamp": "2026-01-01T00:00:00Z"
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ClipItem.self, from: data)

        XCTAssertFalse(decoded.isPinned, "Missing isPinned should default to false for backward compatibility")
        XCTAssertEqual(decoded.content, "old item")
    }

    func testCodableRoundTripWithIsPinnedFalse() throws {
        let item = ClipItem(
            id: UUID(), type: .text, content: "unpinned",
            thumbnailPath: nil, filePath: nil, timestamp: Date(),
            isPinned: false
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ClipItem.self, from: data)

        XCTAssertFalse(decoded.isPinned)
    }
}

// MARK: - ClipItemStore Pin/Unpin Tests

@MainActor
final class ClipItemStorePinTests: XCTestCase {

    private func makeTextItem(_ text: String = "test", isPinned: Bool = false) -> ClipItem {
        ClipItem(
            id: UUID(), type: .text, content: text,
            thumbnailPath: nil, filePath: nil,
            timestamp: Date(), isPinned: isPinned
        )
    }

    private func makeCleanStore() -> ClipItemStore {
        let store = ClipItemStore()
        store.removeAll()
        return store
    }

    // MARK: - togglePin

    func testTogglePinSetsItemPinned() {
        let store = makeCleanStore()
        let item = makeTextItem("pin me")
        store.add(item)
        XCTAssertFalse(store.items[0].isPinned)

        store.togglePin(id: item.id)
        XCTAssertTrue(store.items.first(where: { $0.id == item.id })!.isPinned,
                      "togglePin should set isPinned to true")
    }

    func testTogglePinUnpinsAlreadyPinnedItem() {
        let store = makeCleanStore()
        let item = makeTextItem("pinned", isPinned: true)
        store.add(item)

        store.togglePin(id: item.id)
        XCTAssertFalse(store.items.first(where: { $0.id == item.id })!.isPinned,
                       "togglePin on pinned item should unpin it")
    }

    func testTogglePinWithNonexistentIDIsNoOp() {
        let store = makeCleanStore()
        store.add(makeTextItem("existing"))
        let countBefore = store.items.count

        store.togglePin(id: UUID())
        XCTAssertEqual(store.items.count, countBefore, "Toggling unknown ID should not modify store")
    }

    // MARK: - Pinned-first sorting

    func testPinnedItemsSortedFirst() {
        let store = makeCleanStore()
        let unpinned1 = makeTextItem("unpinned 1")
        let unpinned2 = makeTextItem("unpinned 2")
        store.add(unpinned1)
        store.add(unpinned2)

        // Pin the first one we added (which is now at index 1)
        store.togglePin(id: unpinned1.id)

        XCTAssertTrue(store.items[0].isPinned, "Pinned item should sort to the front")
        XCTAssertEqual(store.items[0].id, unpinned1.id)
    }

    func testMultiplePinnedItemsSortByTimestamp() {
        let store = makeCleanStore()
        let item1 = ClipItem(
            id: UUID(), type: .text, content: "older",
            thumbnailPath: nil, filePath: nil,
            timestamp: Date().addingTimeInterval(-60), isPinned: true
        )
        let item2 = ClipItem(
            id: UUID(), type: .text, content: "newer",
            thumbnailPath: nil, filePath: nil,
            timestamp: Date(), isPinned: true
        )
        store.add(item1)
        store.add(item2)

        // Both pinned — newer should be first
        XCTAssertEqual(store.items[0].content, "newer",
                       "Among pinned items, newer should sort first")
        XCTAssertEqual(store.items[1].content, "older")
    }

    func testPinnedAndUnpinnedSectionOrdering() {
        let store = makeCleanStore()

        // Add 3 items with known timestamps
        let old = ClipItem(id: UUID(), type: .text, content: "old",
                           thumbnailPath: nil, filePath: nil,
                           timestamp: Date().addingTimeInterval(-120))
        let mid = ClipItem(id: UUID(), type: .text, content: "mid",
                           thumbnailPath: nil, filePath: nil,
                           timestamp: Date().addingTimeInterval(-60))
        let recent = ClipItem(id: UUID(), type: .text, content: "recent",
                              thumbnailPath: nil, filePath: nil,
                              timestamp: Date())
        store.add(old)
        store.add(mid)
        store.add(recent)

        // Pin the middle item
        store.togglePin(id: mid.id)

        // Order should be: mid (pinned), recent (unpinned, newest), old (unpinned, oldest)
        XCTAssertEqual(store.items[0].id, mid.id, "Pinned item should be first")
        XCTAssertEqual(store.items[1].id, recent.id, "Newest unpinned should be second")
        XCTAssertEqual(store.items[2].id, old.id, "Oldest unpinned should be last")
    }

    // MARK: - Pinned-aware purge

    func testPurgeSkipsPinnedItems() {
        let store = makeCleanStore()

        // Pin one item
        let pinnedItem = makeTextItem("pinned", isPinned: true)
        store.add(pinnedItem)

        // Fill store to the limit (default 20) with unpinned items
        for i in 0..<20 {
            store.add(makeTextItem("filler \(i)"))
        }

        // The pinned item should survive
        XCTAssertNotNil(store.items.first(where: { $0.id == pinnedItem.id }),
                        "Pinned items should survive purge")
        XCTAssertTrue(store.items.first(where: { $0.id == pinnedItem.id })!.isPinned)
    }

    func testPurgeRemovesOldestUnpinnedItem() {
        let store = makeCleanStore()
        let limit = store.maxItems

        // Add items to fill the store
        var firstUnpinnedID: UUID?
        for i in 0..<limit {
            let item = makeTextItem("item \(i)")
            if i == 0 { firstUnpinnedID = item.id }
            store.add(item)
        }

        // Add one more to trigger purge
        store.add(makeTextItem("overflow"))

        XCTAssertEqual(store.items.count, limit)
        XCTAssertNil(store.items.first(where: { $0.id == firstUnpinnedID }),
                     "Oldest unpinned item should be purged")
    }

    func testPurgeCannotRemoveWhenAllPinned() {
        let store = makeCleanStore()

        // Fill with pinned items
        for i in 0..<20 {
            store.add(makeTextItem("pinned \(i)", isPinned: true))
        }

        // Add one more — all existing are pinned so nothing can be purged
        store.add(makeTextItem("overflow"))

        XCTAssertEqual(store.items.count, 21,
                       "Store should exceed max when all items are pinned and cannot be purged")
    }

    // MARK: - Debounced save / flushSave

    func testFlushSaveDoesNotCrash() {
        let store = makeCleanStore()
        store.add(makeTextItem("save me"))
        store.flushSave()
        // No assertion needed — verifying it doesn't crash
    }

    func testFlushSavePreservesData() async {
        let store = makeCleanStore()
        let item = makeTextItem("persisted")
        store.add(item)
        store.flushSave()

        // flushSave dispatches a detached Task — wait for it to complete
        try? await Task.sleep(nanoseconds: 200_000_000)

        let store2 = ClipItemStore()
        XCTAssertTrue(store2.items.contains(where: { $0.id == item.id }),
                      "flushSave should persist data that survives across store instances")
        store2.removeAll()
    }

    func testFlushSavePreservesPinnedState() async {
        let store = makeCleanStore()
        let item = makeTextItem("pin persist")
        store.add(item)
        store.togglePin(id: item.id)
        store.flushSave()

        // flushSave dispatches a detached Task — wait for it to complete
        try? await Task.sleep(nanoseconds: 200_000_000)

        let store2 = ClipItemStore()
        let reloaded = store2.items.first(where: { $0.id == item.id })
        XCTAssertNotNil(reloaded)
        XCTAssertTrue(reloaded!.isPinned, "Pinned state should survive flushSave + reload")
        store2.removeAll()
    }

    // MARK: - markSensitive preserves isPinned

    func testMarkSensitivePreservesIsPinned() {
        let store = makeCleanStore()
        let item = makeTextItem("sensitive pin")
        store.add(item)
        store.togglePin(id: item.id)

        store.markSensitive(id: item.id)

        let updated = store.items.first(where: { $0.id == item.id })!
        XCTAssertTrue(updated.isSensitive, "Item should be marked sensitive")
        XCTAssertTrue(updated.isPinned, "markSensitive should preserve isPinned")
    }

    func testUnmarkSensitivePreservesIsPinned() {
        let store = makeCleanStore()
        let item = ClipItem(
            id: UUID(), type: .text, content: "test",
            thumbnailPath: nil, filePath: nil, timestamp: Date(),
            isSensitive: true, isPinned: true
        )
        store.add(item)

        store.unmarkSensitive(id: item.id)

        let updated = store.items.first(where: { $0.id == item.id })!
        XCTAssertFalse(updated.isSensitive)
        XCTAssertTrue(updated.isPinned, "unmarkSensitive should preserve isPinned")
    }
}

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
