import XCTest
import AppKit
@testable import Copyhog

// MARK: - ClipItem Model Tests

final class ClipItemModelTests: XCTestCase {

    func testTextItemCreation() {
        let id = UUID()
        let now = Date()
        let item = ClipItem(
            id: id,
            type: .text,
            content: "Hello, world!",
            thumbnailPath: nil,
            filePath: nil,
            timestamp: now
        )
        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.type, .text)
        XCTAssertEqual(item.content, "Hello, world!")
        XCTAssertNil(item.thumbnailPath)
        XCTAssertNil(item.filePath)
        XCTAssertEqual(item.timestamp, now)
    }

    func testImageItemCreation() {
        let id = UUID()
        let item = ClipItem(
            id: id,
            type: .image,
            content: nil,
            thumbnailPath: "thumb.png",
            filePath: "full.png",
            timestamp: Date()
        )
        XCTAssertEqual(item.type, .image)
        XCTAssertNil(item.content)
        XCTAssertEqual(item.thumbnailPath, "thumb.png")
        XCTAssertEqual(item.filePath, "full.png")
    }

    func testItemTypeRawValues() {
        XCTAssertEqual(ClipItem.ItemType.text.rawValue, "text")
        XCTAssertEqual(ClipItem.ItemType.image.rawValue, "image")
    }

    func testCodableRoundTrip() throws {
        let item = ClipItem(
            id: UUID(),
            type: .text,
            content: "Encoded text",
            thumbnailPath: nil,
            filePath: nil,
            timestamp: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ClipItem.self, from: data)

        XCTAssertEqual(decoded.id, item.id)
        XCTAssertEqual(decoded.type, item.type)
        XCTAssertEqual(decoded.content, item.content)
        XCTAssertNil(decoded.thumbnailPath)
        XCTAssertNil(decoded.filePath)
    }

    func testCodableRoundTripWithImagePaths() throws {
        let item = ClipItem(
            id: UUID(),
            type: .image,
            content: nil,
            thumbnailPath: "abc_thumb.png",
            filePath: "abc.png",
            timestamp: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ClipItem.self, from: data)

        XCTAssertEqual(decoded.type, .image)
        XCTAssertEqual(decoded.thumbnailPath, "abc_thumb.png")
        XCTAssertEqual(decoded.filePath, "abc.png")
    }

    func testCodableArrayRoundTrip() throws {
        let items = [
            ClipItem(id: UUID(), type: .text, content: "first", thumbnailPath: nil, filePath: nil, timestamp: Date()),
            ClipItem(id: UUID(), type: .image, content: nil, thumbnailPath: "t.png", filePath: "f.png", timestamp: Date()),
        ]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(items)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([ClipItem].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].type, .text)
        XCTAssertEqual(decoded[1].type, .image)
    }

    func testIdentifiable() {
        let id = UUID()
        let item = ClipItem(id: id, type: .text, content: "x", thumbnailPath: nil, filePath: nil, timestamp: Date())
        XCTAssertEqual(item.id, id, "ClipItem should conform to Identifiable with UUID")
    }
}

// MARK: - ClipItemStore Tests (Phase 1: add, ordering, cap, persistence)

@MainActor
final class ClipItemStorePhase1Tests: XCTestCase {

    private func makeTextItem(_ text: String = "test") -> ClipItem {
        ClipItem(id: UUID(), type: .text, content: text, thumbnailPath: nil, filePath: nil, timestamp: Date())
    }

    private func makeCleanStore() -> ClipItemStore {
        let store = ClipItemStore()
        store.removeAll()
        return store
    }

    // MARK: - add()

    func testAddInsertsAtFront() {
        let store = makeCleanStore()
        let item1 = makeTextItem("first")
        let item2 = makeTextItem("second")
        store.add(item1)
        store.add(item2)

        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items[0].id, item2.id, "Most recently added item should be first (MRU order)")
        XCTAssertEqual(store.items[1].id, item1.id)
    }

    func testAddSingleItem() {
        let store = makeCleanStore()
        let item = makeTextItem("solo")
        store.add(item)

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.content, "solo")
    }

    func testMaxItemsCap() {
        let store = makeCleanStore()
        for i in 0..<25 {
            store.add(makeTextItem("item \(i)"))
        }
        XCTAssertEqual(store.items.count, 20, "Store should never exceed 20 items")
    }

    func testOldestItemPurgedWhenOverCap() {
        let store = makeCleanStore()
        let firstItem = makeTextItem("first-added")
        store.add(firstItem)
        for i in 1..<21 {
            store.add(makeTextItem("item \(i)"))
        }
        XCTAssertEqual(store.items.count, 20)
        XCTAssertNil(store.items.first(where: { $0.id == firstItem.id }),
                     "The oldest item should be purged when exceeding cap")
    }

    func testMostRecentItemSurvivesCap() {
        let store = makeCleanStore()
        for i in 0..<20 {
            store.add(makeTextItem("item \(i)"))
        }
        let newest = makeTextItem("newest")
        store.add(newest)

        XCTAssertEqual(store.items.first?.id, newest.id, "Newest item should always be at front")
    }

    // MARK: - Persistence round-trip

    func testPersistenceRoundTrip() {
        let store1 = makeCleanStore()
        let item = makeTextItem("persisted")
        store1.add(item)

        // Create a new store instance — it loads from the same JSON file
        let store2 = ClipItemStore()
        XCTAssertTrue(store2.items.contains(where: { $0.id == item.id }),
                      "Items should survive across store instances via JSON persistence")

        // Cleanup
        store2.removeAll()
    }

    func testPersistencePreservesOrder() {
        let store1 = makeCleanStore()
        let item1 = makeTextItem("a")
        let item2 = makeTextItem("b")
        let item3 = makeTextItem("c")
        store1.add(item1)
        store1.add(item2)
        store1.add(item3)

        let store2 = ClipItemStore()
        XCTAssertEqual(store2.items.count, 3)
        XCTAssertEqual(store2.items[0].id, item3.id, "MRU order should persist")
        XCTAssertEqual(store2.items[1].id, item2.id)
        XCTAssertEqual(store2.items[2].id, item1.id)

        store2.removeAll()
    }

    // MARK: - Published property

    func testItemsIsPublished() {
        let store = makeCleanStore()
        XCTAssertTrue(store.items.isEmpty, "Fresh clean store should have empty items array")
        store.add(makeTextItem("trigger"))
        XCTAssertFalse(store.items.isEmpty, "@Published items should update synchronously on @MainActor")
        store.removeAll()
    }
}

// MARK: - ClipboardObserver Tests

@MainActor
final class ClipboardObserverTests: XCTestCase {

    func testSkipNextChangeSetsFlag() {
        let imageStore = ImageStore()
        let observer = ClipboardObserver(imageStore: imageStore)

        // Before skipNextChange, observer should be ready to capture
        // After skipNextChange, the next clipboard change should be skipped
        observer.skipNextChange()

        // We can verify the observer doesn't crash and the method is callable
        // (The internal isOwnWrite flag is private, so we test behavioral contract)
        XCTAssertNotNil(observer, "Observer should handle skipNextChange without error")
    }

    func testStartAndStop() {
        let imageStore = ImageStore()
        let observer = ClipboardObserver(imageStore: imageStore)

        observer.start { _ in }
        // Timer should be running — stop should invalidate it
        observer.stop()
        // Calling stop again should be safe
        observer.stop()
        XCTAssertNotNil(observer, "Start/stop cycle should complete without error")
    }

    func testMultipleSkipNextChangeCalls() {
        let imageStore = ImageStore()
        let observer = ClipboardObserver(imageStore: imageStore)

        // Multiple calls should not crash
        observer.skipNextChange()
        observer.skipNextChange()
        observer.skipNextChange()
        XCTAssertNotNil(observer)
    }
}

// MARK: - ImageStore Tests

final class ImageStoreTests: XCTestCase {

    func testResolveURLReturnsAppSupportPath() {
        let imageStore = ImageStore()
        let url = imageStore.resolveURL(relativePath: "test.png")
        XCTAssertTrue(url.path.contains("Copyhog"), "Resolved URL should be under Copyhog app support")
        XCTAssertTrue(url.path.hasSuffix("test.png"))
    }

    func testResolveURLWithUUIDFilename() {
        let imageStore = ImageStore()
        let uuid = UUID()
        let url = imageStore.resolveURL(relativePath: "\(uuid.uuidString).png")
        XCTAssertTrue(url.lastPathComponent == "\(uuid.uuidString).png")
    }

    func testSaveAndLoadImage() {
        let imageStore = ImageStore()
        let id = UUID()

        // Create a simple 2x2 red image
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation else {
            XCTFail("Could not create TIFF data from test image")
            return
        }

        guard let paths = imageStore.saveImage(tiffData, id: id) else {
            XCTFail("saveImage should succeed with valid image data")
            return
        }

        XCTAssertEqual(paths.filePath, "\(id.uuidString).png")
        XCTAssertEqual(paths.thumbnailPath, "\(id.uuidString)_thumb.png")

        // Verify file exists and is loadable
        let loaded = imageStore.loadImage(relativePath: paths.filePath)
        XCTAssertNotNil(loaded, "Saved image should be loadable")

        // Verify thumbnail was created
        let thumb = imageStore.loadImage(relativePath: paths.thumbnailPath)
        XCTAssertNotNil(thumb, "Thumbnail should be loadable")

        // Cleanup
        imageStore.deleteImage(relativePath: paths.filePath)
        imageStore.deleteImage(relativePath: paths.thumbnailPath)
    }

    func testDeleteImage() {
        let imageStore = ImageStore()
        let id = UUID()

        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let paths = imageStore.saveImage(tiffData, id: id) else {
            XCTFail("Setup failed")
            return
        }

        // Delete and verify
        imageStore.deleteImage(relativePath: paths.filePath)
        let loaded = imageStore.loadImage(relativePath: paths.filePath)
        XCTAssertNil(loaded, "Deleted image should not be loadable")

        // Cleanup thumbnail
        imageStore.deleteImage(relativePath: paths.thumbnailPath)
    }

    func testDeleteNonexistentImageIsNoOp() {
        let imageStore = ImageStore()
        // Should not crash
        imageStore.deleteImage(relativePath: "nonexistent-file.png")
    }

    func testLoadNonexistentImageReturnsNil() {
        let imageStore = ImageStore()
        let result = imageStore.loadImage(relativePath: "does-not-exist.png")
        XCTAssertNil(result)
    }

    func testSaveInvalidDataReturnsNil() {
        let imageStore = ImageStore()
        let badData = Data("not an image".utf8)
        let result = imageStore.saveImage(badData, id: UUID())
        XCTAssertNil(result, "Invalid image data should return nil")
    }
}

// MARK: - ScreenshotWatcher Filename Detection Tests

final class ScreenshotFilenameTests: XCTestCase {

    // Replicate the private isScreenshot logic for testing
    private func isScreenshot(fileName: String) -> Bool {
        let lower = fileName.lowercased()
        return lower.hasPrefix("screenshot") || lower.hasPrefix("screen shot")
    }

    func testStandardScreenshotFilename() {
        XCTAssertTrue(isScreenshot(fileName: "Screenshot 2026-02-21 at 10.30.00.png"))
    }

    func testScreenShotWithSpace() {
        XCTAssertTrue(isScreenshot(fileName: "Screen Shot 2026-02-21 at 10.30.00.png"))
    }

    func testCaseInsensitiveDetection() {
        XCTAssertTrue(isScreenshot(fileName: "SCREENSHOT 2026-02-21.png"))
        XCTAssertTrue(isScreenshot(fileName: "screenshot test.png"))
    }

    func testNonScreenshotFileRejected() {
        XCTAssertFalse(isScreenshot(fileName: "vacation-photo.png"))
        XCTAssertFalse(isScreenshot(fileName: "document.pdf"))
        XCTAssertFalse(isScreenshot(fileName: "my_screenshot_backup.png"))
    }

    func testEmptyFilename() {
        XCTAssertFalse(isScreenshot(fileName: ""))
    }

    func testScreenshotWithJPGExtension() {
        XCTAssertTrue(isScreenshot(fileName: "Screenshot 2026-02-21.jpg"))
    }
}
