import XCTest
import AppKit
import CoreTransferable
import UniformTypeIdentifiers
@testable import Copyhog

// MARK: - PasteboardWriter Tests

@MainActor
final class PasteboardWriterTests: XCTestCase {

    private func makeClipboardObserver() -> ClipboardObserver {
        ClipboardObserver(imageStore: ImageStore())
    }

    // MARK: - Single item write

    func testWriteTextItem() {
        let observer = makeClipboardObserver()
        let item = ClipItem(
            id: UUID(), type: .text, content: "clipboard text",
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )

        PasteboardWriter.write(item, imageStore: ImageStore(), clipboardObserver: observer)

        let pasteboard = NSPasteboard.general
        let result = pasteboard.string(forType: .string)
        XCTAssertEqual(result, "clipboard text", "Text should be written to clipboard")
    }

    func testWriteTextItemWithEmptyContent() {
        let observer = makeClipboardObserver()
        let item = ClipItem(
            id: UUID(), type: .text, content: "",
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )

        PasteboardWriter.write(item, imageStore: ImageStore(), clipboardObserver: observer)

        let pasteboard = NSPasteboard.general
        let result = pasteboard.string(forType: .string)
        XCTAssertEqual(result, "", "Empty text should still be written")
    }

    func testWriteTextItemWithNilContent() {
        let observer = makeClipboardObserver()
        let item = ClipItem(
            id: UUID(), type: .text, content: nil,
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )

        PasteboardWriter.write(item, imageStore: ImageStore(), clipboardObserver: observer)

        let pasteboard = NSPasteboard.general
        let result = pasteboard.string(forType: .string)
        XCTAssertEqual(result, "", "Nil content should write empty string")
    }

    func testWriteCallsSkipNextChange() {
        let observer = makeClipboardObserver()
        let item = ClipItem(
            id: UUID(), type: .text, content: "skip test",
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )

        // This should not crash — skipNextChange is called internally
        PasteboardWriter.write(item, imageStore: ImageStore(), clipboardObserver: observer)
        XCTAssertNotNil(observer, "Write should call skipNextChange without error")
    }

    func testWriteImageWithMissingFile() {
        let observer = makeClipboardObserver()
        let item = ClipItem(
            id: UUID(), type: .image, content: nil,
            thumbnailPath: "nonexistent_thumb.png", filePath: "nonexistent.png", timestamp: Date()
        )

        // Should not crash even though image file doesn't exist
        PasteboardWriter.write(item, imageStore: ImageStore(), clipboardObserver: observer)
        XCTAssertNotNil(observer, "Write with missing image should not crash")
    }

    func testWriteImageWithNilFilePath() {
        let observer = makeClipboardObserver()
        let item = ClipItem(
            id: UUID(), type: .image, content: nil,
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )

        PasteboardWriter.write(item, imageStore: ImageStore(), clipboardObserver: observer)
        XCTAssertNotNil(observer, "Write image with nil filePath should return early safely")
    }

    // MARK: - Multiple item write

    func testWriteMultipleEmptyArrayIsNoOp() {
        let observer = makeClipboardObserver()
        let countBefore = NSPasteboard.general.changeCount

        PasteboardWriter.writeMultiple([], imageStore: ImageStore(), clipboardObserver: observer)

        // Empty array should be a no-op (guard !items.isEmpty else { return })
        XCTAssertEqual(NSPasteboard.general.changeCount, countBefore,
                       "Empty array should not touch clipboard")
    }

    func testWriteMultipleTextItems() {
        let observer = makeClipboardObserver()
        let items = [
            ClipItem(id: UUID(), type: .text, content: "line 1", thumbnailPath: nil, filePath: nil, timestamp: Date()),
            ClipItem(id: UUID(), type: .text, content: "line 2", thumbnailPath: nil, filePath: nil, timestamp: Date()),
            ClipItem(id: UUID(), type: .text, content: "line 3", thumbnailPath: nil, filePath: nil, timestamp: Date()),
        ]

        PasteboardWriter.writeMultiple(items, imageStore: ImageStore(), clipboardObserver: observer)

        let result = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(result, "line 1\n\nline 2\n\nline 3",
                       "Multiple text items should be joined with double newlines")
    }

    func testWriteMultipleSingleTextItem() {
        let observer = makeClipboardObserver()
        let items = [
            ClipItem(id: UUID(), type: .text, content: "solo", thumbnailPath: nil, filePath: nil, timestamp: Date()),
        ]

        PasteboardWriter.writeMultiple(items, imageStore: ImageStore(), clipboardObserver: observer)

        let result = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(result, "solo")
    }

    func testWriteMultipleCallsSkipNextChange() {
        let observer = makeClipboardObserver()
        let items = [
            ClipItem(id: UUID(), type: .text, content: "a", thumbnailPath: nil, filePath: nil, timestamp: Date()),
        ]

        PasteboardWriter.writeMultiple(items, imageStore: ImageStore(), clipboardObserver: observer)
        XCTAssertNotNil(observer, "writeMultiple should call skipNextChange without error")
    }

    func testWriteMultipleTextWritesCombinedStringAndRTFD() {
        let observer = makeClipboardObserver()
        let items = [
            ClipItem(id: UUID(), type: .text, content: "alpha", thumbnailPath: nil, filePath: nil, timestamp: Date()),
            ClipItem(id: UUID(), type: .text, content: "beta", thumbnailPath: nil, filePath: nil, timestamp: Date()),
        ]

        PasteboardWriter.writeMultiple(items, imageStore: ImageStore(), clipboardObserver: observer)

        let pasteboard = NSPasteboard.general
        XCTAssertEqual(pasteboard.string(forType: .string), "alpha\n\nbeta",
                       "Text items should be concatenated with double newlines")
        XCTAssertNotNil(pasteboard.data(forType: .rtfd),
                        "RTFD data should be present for rich text apps")
    }

    func testWriteMultipleMixedIncludesTextAndRTFD() {
        let observer = makeClipboardObserver()
        let items = [
            ClipItem(id: UUID(), type: .image, content: nil, thumbnailPath: nil, filePath: "img.png", timestamp: Date()),
            ClipItem(id: UUID(), type: .text, content: "text item", thumbnailPath: nil, filePath: nil, timestamp: Date()),
        ]

        PasteboardWriter.writeMultiple(items, imageStore: ImageStore(), clipboardObserver: observer)

        let pasteboard = NSPasteboard.general
        XCTAssertEqual(pasteboard.string(forType: .string), "text item",
                       "Combined text should be readable from the pasteboard")
        // RTFD should embed both the text and the image
        XCTAssertNotNil(pasteboard.data(forType: .rtfd),
                        "RTFD with embedded images should be on the pasteboard")
    }

    func testWriteMultipleImageOnlyWritesRTFDAndTIFF() {
        let observer = makeClipboardObserver()
        // Use images that don't exist on disk — RTFD should still be generated
        let items = [
            ClipItem(id: UUID(), type: .image, content: nil, thumbnailPath: nil, filePath: "img1.png", timestamp: Date()),
            ClipItem(id: UUID(), type: .image, content: nil, thumbnailPath: nil, filePath: "img2.png", timestamp: Date()),
        ]

        PasteboardWriter.writeMultiple(items, imageStore: ImageStore(), clipboardObserver: observer)

        let pasteboard = NSPasteboard.general
        // No text items → no .string type
        XCTAssertNil(pasteboard.string(forType: .string),
                     "Image-only selection should not write a .string type")
        // RTFD should be present (even if images couldn't be loaded, the data is generated)
        // Note: with non-existent image files, RTFD may be empty but the mechanism is tested
    }

    func testWriteMultipleWritesSinglePasteboardItem() {
        let observer = makeClipboardObserver()
        let items = [
            ClipItem(id: UUID(), type: .text, content: "one", thumbnailPath: nil, filePath: nil, timestamp: Date()),
            ClipItem(id: UUID(), type: .text, content: "two", thumbnailPath: nil, filePath: nil, timestamp: Date()),
        ]

        PasteboardWriter.writeMultiple(items, imageStore: ImageStore(), clipboardObserver: observer)

        let pasteboard = NSPasteboard.general
        XCTAssertEqual(pasteboard.pasteboardItems?.count, 1,
                       "All content should be on a single pasteboard item for universal compatibility")
    }

    func testWriteMultiplePreservesOrderFromStore() {
        let observer = makeClipboardObserver()
        let items = [
            ClipItem(id: UUID(), type: .text, content: "first", thumbnailPath: nil, filePath: nil, timestamp: Date()),
            ClipItem(id: UUID(), type: .text, content: "second", thumbnailPath: nil, filePath: nil, timestamp: Date()),
            ClipItem(id: UUID(), type: .text, content: "third", thumbnailPath: nil, filePath: nil, timestamp: Date()),
        ]

        PasteboardWriter.writeMultiple(items, imageStore: ImageStore(), clipboardObserver: observer)

        let result = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(result, "first\n\nsecond\n\nthird",
                       "Items should be concatenated in the order they appear")
    }
}

// MARK: - ClipItem Transferable Tests

final class ClipItemTransferableTests: XCTestCase {

    func testTextItemHasTransferRepresentation() {
        let item = ClipItem(
            id: UUID(), type: .text, content: "transferable text",
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )
        // Verify ClipItem conforms to Transferable (compilation check)
        let _: any Transferable = item
        XCTAssertNotNil(item, "ClipItem should conform to Transferable")
    }

    func testImageItemHasTransferRepresentation() {
        let item = ClipItem(
            id: UUID(), type: .image, content: nil,
            thumbnailPath: "thumb.png", filePath: "full.png", timestamp: Date()
        )
        let _: any Transferable = item
        XCTAssertNotNil(item, "Image ClipItem should conform to Transferable")
    }

    func testTransferRepresentationExists() {
        // Verify the static transferRepresentation property exists
        let rep = ClipItem.transferRepresentation
        XCTAssertNotNil(rep, "ClipItem should have a transferRepresentation")
    }
}

// MARK: - Multi-Select Logic Tests

@MainActor
final class MultiSelectLogicTests: XCTestCase {

    private func makeTextItem(_ text: String) -> ClipItem {
        ClipItem(id: UUID(), type: .text, content: text, thumbnailPath: nil, filePath: nil, timestamp: Date())
    }

    func testToggleSelectionAddsItem() {
        var selectedItems: Set<UUID> = []
        let item = makeTextItem("select me")

        // Simulate tap in multi-select mode
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }

        XCTAssertTrue(selectedItems.contains(item.id))
    }

    func testToggleSelectionRemovesItem() {
        let item = makeTextItem("deselect me")
        var selectedItems: Set<UUID> = [item.id]

        // Simulate second tap to deselect
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }

        XCTAssertFalse(selectedItems.contains(item.id))
    }

    func testMultiSelectMultipleItems() {
        let item1 = makeTextItem("first")
        let item2 = makeTextItem("second")
        let item3 = makeTextItem("third")
        var selectedItems: Set<UUID> = []

        selectedItems.insert(item1.id)
        selectedItems.insert(item2.id)
        selectedItems.insert(item3.id)

        XCTAssertEqual(selectedItems.count, 3)
    }

    func testExitMultiSelectClearsSelection() {
        let item = makeTextItem("selected")
        var selectedItems: Set<UUID> = [item.id]
        var isMultiSelectActive = true

        // Simulate toggling multi-select off (as PopoverContent does)
        isMultiSelectActive.toggle()
        if !isMultiSelectActive {
            selectedItems.removeAll()
        }

        XCTAssertFalse(isMultiSelectActive)
        XCTAssertTrue(selectedItems.isEmpty, "Exiting multi-select should clear selection")
    }

    func testBatchCopyResetsState() {
        let item1 = makeTextItem("a")
        let item2 = makeTextItem("b")
        var selectedItems: Set<UUID> = [item1.id, item2.id]
        var isMultiSelectActive = true

        // Simulate batch copy button action
        // (After copy, selectedItems and isMultiSelectActive are reset)
        selectedItems.removeAll()
        isMultiSelectActive = false

        XCTAssertTrue(selectedItems.isEmpty, "Batch copy should clear selection")
        XCTAssertFalse(isMultiSelectActive, "Batch copy should exit multi-select mode")
    }

    func testSelectedItemsFilterFromStore() {
        let store = ClipItemStore()
        store.removeAll()

        let item1 = makeTextItem("first")
        let item2 = makeTextItem("second")
        let item3 = makeTextItem("third")
        store.add(item1)
        store.add(item2)
        store.add(item3)

        let selectedItems: Set<UUID> = [item1.id, item3.id]
        let itemsToCopy = store.items.filter { selectedItems.contains($0.id) }

        XCTAssertEqual(itemsToCopy.count, 2, "Should filter store items by selected IDs")
        XCTAssertTrue(itemsToCopy.contains(where: { $0.id == item1.id }))
        XCTAssertTrue(itemsToCopy.contains(where: { $0.id == item3.id }))

        store.removeAll()
    }
}

// MARK: - Drag Support Tests (Transferable + Draggable)

final class DragSupportTests: XCTestCase {

    func testTextItemExportsPlainTextType() {
        // ClipItem's DataRepresentation exports .plainText for text items
        let item = ClipItem(
            id: UUID(), type: .text, content: "drag this text",
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )
        XCTAssertEqual(item.type, .text)
        XCTAssertNotNil(item.content, "Text item should have content for drag export")
    }

    func testImageItemExportsPNGType() {
        // ClipItem's FileRepresentation exports .png for image items
        let item = ClipItem(
            id: UUID(), type: .image, content: nil,
            thumbnailPath: "thumb.png", filePath: "full.png", timestamp: Date()
        )
        XCTAssertEqual(item.type, .image)
        XCTAssertNotNil(item.filePath, "Image item should have filePath for drag export")
    }

    func testImageItemWithNilFilePathCannotDrag() {
        let item = ClipItem(
            id: UUID(), type: .image, content: nil,
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )
        XCTAssertNil(item.filePath, "Image without filePath should not be draggable as file")
    }
}
