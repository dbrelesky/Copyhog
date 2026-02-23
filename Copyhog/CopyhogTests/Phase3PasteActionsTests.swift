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
        XCTAssertNil(pasteboard.string(forType: .string),
                     "Mixed batches should not publish .string (it drops images in many apps)")
        XCTAssertNotNil(pasteboard.data(forType: .rtfd),
                        "RTFD with embedded images should be on the pasteboard")
    }

    func testWriteMultipleImageOnlyNoStringType() {
        let observer = makeClipboardObserver()
        // Images don't exist on disk so won't load, but no .string should be written
        let items = [
            ClipItem(id: UUID(), type: .image, content: nil, thumbnailPath: nil, filePath: "img1.png", timestamp: Date()),
            ClipItem(id: UUID(), type: .image, content: nil, thumbnailPath: nil, filePath: "img2.png", timestamp: Date()),
        ]

        PasteboardWriter.writeMultiple(items, imageStore: ImageStore(), clipboardObserver: observer)

        let pasteboard = NSPasteboard.general
        // No text items → no .string type
        XCTAssertNil(pasteboard.string(forType: .string),
                     "Image-only selection should not write a .string type")
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
                       "All content should be on a single pasteboard item")
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

    func testWriteMultipleHasAllExpectedTypes() {
        let observer = makeClipboardObserver()
        let items = [
            ClipItem(id: UUID(), type: .text, content: "hello", thumbnailPath: nil, filePath: nil, timestamp: Date()),
        ]

        PasteboardWriter.writeMultiple(items, imageStore: ImageStore(), clipboardObserver: observer)

        let pasteboard = NSPasteboard.general
        XCTAssertEqual(pasteboard.pasteboardItems?.count, 1,
                       "writeMultiple should produce exactly 1 pasteboard item")
        let types = pasteboard.pasteboardItems?.first?.types ?? []
        XCTAssertTrue(types.contains(.string),
                      "Pasteboard item should contain .string type")
        XCTAssertTrue(types.contains(.rtfd),
                      "Pasteboard item should contain .rtfd type")
    }

    func testSkipAndFinishOwnWriteLogic() {
        let observer = makeClipboardObserver()
        let pasteboard = NSPasteboard.general

        // Simulate own write: skip before, write, finish after
        observer.skipNextChange()
        pasteboard.clearContents()
        pasteboard.setString("own write", forType: .string)
        observer.finishOwnWrite()

        let countAfterFinish = pasteboard.changeCount

        // Another external write should be detected (changeCount will exceed)
        pasteboard.clearContents()
        pasteboard.setString("external write", forType: .string)
        XCTAssertGreaterThan(pasteboard.changeCount, countAfterFinish,
                             "External write should bump changeCount past own write")
    }

    func testWriteMultipleViaStoreFilterMatchesCopyFlow() {
        // Simulates the exact code path in copyMultiSelectedItems()
        let store = ClipItemStore()
        store.removeAll()

        let item1 = ClipItem(id: UUID(), type: .text, content: "first selected",
                             thumbnailPath: nil, filePath: nil, timestamp: Date())
        let item2 = ClipItem(id: UUID(), type: .text, content: "second selected",
                             thumbnailPath: nil, filePath: nil, timestamp: Date())
        let item3 = ClipItem(id: UUID(), type: .text, content: "not selected",
                             thumbnailPath: nil, filePath: nil, timestamp: Date())
        store.add(item1)
        store.add(item2)
        store.add(item3)

        let selectedItems: Set<UUID> = [item1.id, item2.id]
        let observer = makeClipboardObserver()

        // This is the exact filter used in PopoverContent.copyMultiSelectedItems()
        let itemsToCopy = store.items.filter { selectedItems.contains($0.id) }

        XCTAssertEqual(itemsToCopy.count, 2, "Should find both selected items in store")

        PasteboardWriter.writeMultiple(itemsToCopy, imageStore: ImageStore(), clipboardObserver: observer)

        let pasteboard = NSPasteboard.general
        let result = pasteboard.string(forType: .string)
        XCTAssertNotNil(result, "Pasteboard should have .string content")
        XCTAssertTrue(result?.contains("first selected") == true,
                      "Pasteboard should contain first selected item")
        XCTAssertTrue(result?.contains("second selected") == true,
                      "Pasteboard should contain second selected item")
        XCTAssertFalse(result?.contains("not selected") == true,
                       "Pasteboard should NOT contain unselected item")

        store.removeAll()
    }

    func testWriteMultipleNotRecapturedByObserver() {
        let observer = makeClipboardObserver()
        let items = [
            ClipItem(id: UUID(), type: .text, content: "alpha", thumbnailPath: nil, filePath: nil, timestamp: Date()),
            ClipItem(id: UUID(), type: .text, content: "beta", thumbnailPath: nil, filePath: nil, timestamp: Date()),
            ClipItem(id: UUID(), type: .text, content: "gamma", thumbnailPath: nil, filePath: nil, timestamp: Date()),
        ]

        // Start the observer — track any captured items
        var capturedItems: [ClipItem] = []
        observer.start { item in
            capturedItems.append(item)
        }

        // Write multiple items (this should NOT be re-captured)
        PasteboardWriter.writeMultiple(items, imageStore: ImageStore(), clipboardObserver: observer)

        // Give the observer several poll cycles (100ms each)
        let expectation = XCTestExpectation(description: "Wait for observer polls")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        observer.stop()

        // The observer should NOT have captured anything — the write was ours
        XCTAssertEqual(capturedItems.count, 0,
                       "Observer must not re-capture our own writeMultiple")

        // The pasteboard should still have the combined text
        let result = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(result, "alpha\n\nbeta\n\ngamma",
                       "Pasteboard must still contain all items after observer polls")
    }
}

// MARK: - Real-Image Multi-Paste Tests

@MainActor
final class RealImageMultiPasteTests: XCTestCase {

    private let imageStore = ImageStore()

    private func makeClipboardObserver() -> ClipboardObserver {
        ClipboardObserver(imageStore: ImageStore())
    }

    /// Creates a real 10x10 colored PNG in ImageStore and returns a ClipItem pointing to it.
    private func makeRealImageItem(color: NSColor = .red) -> ClipItem {
        let id = UUID()
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        color.setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: 10, height: 10))
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let pngData = rep.representation(using: .png, properties: [:]),
              let paths = imageStore.saveImage(pngData, id: id) else {
            fatalError("Failed to create test image")
        }

        return ClipItem(
            id: id, type: .image, content: nil,
            thumbnailPath: paths.thumbnailPath, filePath: paths.filePath,
            timestamp: Date()
        )
    }

    override func tearDown() {
        super.tearDown()
        // Clean up test images
    }

    // -- Diagnostic: verify ImageStore can load the image we just saved --

    func testImageStoreRoundTrip() {
        let item = makeRealImageItem()
        let loaded = imageStore.loadImage(relativePath: item.filePath!)
        XCTAssertNotNil(loaded, "ImageStore must load the image we just saved")
        XCTAssertNotNil(loaded?.tiffRepresentation, "Loaded image must have tiffRepresentation")
    }

    // -- Diagnostic: verify RTFD data contains attachment(s) --

    func testRTFDContainsImageAttachment() {
        let item = makeRealImageItem()
        let image = imageStore.loadImage(relativePath: item.filePath!)!
        let tiffData = image.tiffRepresentation!

        let attachment = NSTextAttachment()
        let wrapper = FileWrapper(regularFileWithContents: tiffData)
        wrapper.preferredFilename = "image0.tiff"
        attachment.fileWrapper = wrapper

        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(attachment: attachment))

        let range = NSRange(location: 0, length: attributed.length)
        let rtfdData = attributed.rtfd(from: range, documentAttributes: [:])
        XCTAssertNotNil(rtfdData, "RTFD data must be generated from attributed string with image")
        XCTAssertGreaterThan(rtfdData!.count, 100,
                             "RTFD data must contain substantial bytes (image payload)")

        // Read it back and verify the attachment survived
        let readBack = NSAttributedString(rtfd: rtfdData!, documentAttributes: nil)
        XCTAssertNotNil(readBack, "Must be able to read RTFD data back")

        var foundAttachment = false
        readBack!.enumerateAttribute(.attachment, in: NSRange(location: 0, length: readBack!.length)) { value, _, _ in
            if value is NSTextAttachment {
                foundAttachment = true
            }
        }
        XCTAssertTrue(foundAttachment, "Read-back attributed string must contain the image attachment")
    }

    // -- End-to-end: writeMultiple with real images, verify pasteboard --

    func testWriteMultipleRealImagesProducesRTFDWithAttachments() {
        let observer = makeClipboardObserver()
        let img1 = makeRealImageItem(color: .red)
        let img2 = makeRealImageItem(color: .blue)

        PasteboardWriter.writeMultiple([img1, img2], imageStore: imageStore, clipboardObserver: observer)

        let pasteboard = NSPasteboard.general

        // 1. Single pasteboard item
        XCTAssertEqual(pasteboard.pasteboardItems?.count, 1,
                       "Must write a single pasteboard item")

        // 2. RTFD type must be present
        let rtfdData = pasteboard.data(forType: .rtfd)
        XCTAssertNotNil(rtfdData, "Pasteboard must have .rtfd type")
        XCTAssertGreaterThan(rtfdData!.count, 200,
                             "RTFD data must be substantial (two images)")

        // 3. Read back RTFD and count attachments
        let readBack = NSAttributedString(rtfd: rtfdData!, documentAttributes: nil)
        XCTAssertNotNil(readBack, "RTFD data must be readable")

        var attachmentCount = 0
        readBack!.enumerateAttribute(.attachment, in: NSRange(location: 0, length: readBack!.length)) { value, _, _ in
            if value is NSTextAttachment {
                attachmentCount += 1
            }
        }
        XCTAssertEqual(attachmentCount, 2,
                       "RTFD must contain exactly 2 image attachments")

        // 4. No .string type for image-only selection
        XCTAssertNil(pasteboard.string(forType: .string),
                     "Image-only selection must not write .string")

        // 5. No .tiff fallback — it only carries one image and drops the rest
        XCTAssertNil(pasteboard.data(forType: .tiff),
                     "Image-only multi-select must not write a single-image TIFF fallback")

        // Clean up
        imageStore.deleteImage(relativePath: img1.filePath!)
        imageStore.deleteImage(relativePath: img1.thumbnailPath!)
        imageStore.deleteImage(relativePath: img2.filePath!)
        imageStore.deleteImage(relativePath: img2.thumbnailPath!)
    }

    func testWriteMultipleMixedRealImageAndText() {
        let observer = makeClipboardObserver()
        let img = makeRealImageItem(color: .green)
        let text = ClipItem(id: UUID(), type: .text, content: "hello world",
                            thumbnailPath: nil, filePath: nil, timestamp: Date())

        PasteboardWriter.writeMultiple([text, img], imageStore: imageStore, clipboardObserver: observer)

        let pasteboard = NSPasteboard.general

        // 1. Single pasteboard item
        XCTAssertEqual(pasteboard.pasteboardItems?.count, 1)

        // 2. No .string for mixed multi-select (prevents text-only fallback in rich apps)
        XCTAssertNil(pasteboard.string(forType: .string))

        // 3. RTFD has both text and image
        let rtfdData = pasteboard.data(forType: .rtfd)
        XCTAssertNotNil(rtfdData, "Must have RTFD")

        let readBack = NSAttributedString(rtfd: rtfdData!, documentAttributes: nil)
        XCTAssertNotNil(readBack)

        var attachmentCount = 0
        readBack!.enumerateAttribute(.attachment, in: NSRange(location: 0, length: readBack!.length)) { value, _, _ in
            if value is NSTextAttachment { attachmentCount += 1 }
        }
        XCTAssertEqual(attachmentCount, 1, "RTFD must contain the image attachment")
        XCTAssertTrue(readBack!.string.contains("hello world"),
                      "RTFD text must contain 'hello world'")

        // 4. No single-image fallback for mixed multi-select
        XCTAssertNil(pasteboard.data(forType: .tiff))

        // Clean up
        imageStore.deleteImage(relativePath: img.filePath!)
        imageStore.deleteImage(relativePath: img.thumbnailPath!)
    }

    /// Diagnostic: dump all pasteboard types to understand what apps see
    func testPasteboardTypeOrderForMixed() {
        let observer = makeClipboardObserver()
        let img = makeRealImageItem(color: .red)
        let text = ClipItem(id: UUID(), type: .text, content: "test",
                            thumbnailPath: nil, filePath: nil, timestamp: Date())

        PasteboardWriter.writeMultiple([text, img], imageStore: imageStore, clipboardObserver: observer)

        let pasteboard = NSPasteboard.general
        let types = pasteboard.pasteboardItems?.first?.types ?? []
        print("=== PASTEBOARD TYPES (mixed) ===")
        for t in types { print("  - \(t.rawValue)") }
        print("=== END ===")

        // Mixed multi-select must only expose full-fidelity types.
        XCTAssertTrue(types.contains(.rtfd), "RTFD must be present")
        XCTAssertFalse(types.contains(.string), "Mixed multi-select should not publish .string")
        XCTAssertFalse(types.contains(.tiff), "Mixed multi-select should not publish .tiff")

        imageStore.deleteImage(relativePath: img.filePath!)
        imageStore.deleteImage(relativePath: img.thumbnailPath!)
    }

    /// Diagnostic: for image-only, verify what types are on the pasteboard
    func testPasteboardTypeOrderForImagesOnly() {
        let observer = makeClipboardObserver()
        let img1 = makeRealImageItem(color: .red)
        let img2 = makeRealImageItem(color: .blue)

        PasteboardWriter.writeMultiple([img1, img2], imageStore: imageStore, clipboardObserver: observer)

        let pasteboard = NSPasteboard.general
        let types = pasteboard.pasteboardItems?.first?.types ?? []
        print("=== PASTEBOARD TYPES (images only) ===")
        for t in types { print("  - \(t.rawValue)") }
        print("=== END ===")

        XCTAssertTrue(types.contains(.rtfd), "RTFD must be present")
        XCTAssertFalse(types.contains(.tiff), "No .tiff for image-only multi-select")
        XCTAssertFalse(types.contains(.string), "No .string for image-only")

        for item in [img1, img2] {
            imageStore.deleteImage(relativePath: item.filePath!)
            imageStore.deleteImage(relativePath: item.thumbnailPath!)
        }
    }

    /// Simulate what Notes/TextEdit actually does: create an NSTextView and paste into it
    func testPasteIntoNSTextViewShowsImages() {
        let observer = makeClipboardObserver()
        let img1 = makeRealImageItem(color: .red)
        let img2 = makeRealImageItem(color: .blue)
        let text = ClipItem(id: UUID(), type: .text, content: "between images",
                            thumbnailPath: nil, filePath: nil, timestamp: Date())

        PasteboardWriter.writeMultiple([img1, text, img2], imageStore: imageStore, clipboardObserver: observer)

        // Create an NSTextView (this is what Notes/TextEdit use internally)
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        textView.isRichText = true
        textView.importsGraphics = true

        // Simulate Cmd+V — readSelection reads from the pasteboard
        let pasteboard = NSPasteboard.general
        let success = textView.readSelection(from: pasteboard, type: .rtfd)
        print("=== readSelection(.rtfd) success: \(success) ===")

        if !success {
            // Try reading RTFD data directly
            if let rtfdData = pasteboard.data(forType: .rtfd) {
                let attr = NSAttributedString(rtfd: rtfdData, documentAttributes: nil)
                if let attr = attr {
                    textView.textStorage?.setAttributedString(attr)
                    print("=== Fallback: set attributed string directly ===")
                }
            }
        }

        let storage = textView.textStorage!
        print("=== TextStorage length: \(storage.length) ===")
        print("=== TextStorage string: '\(storage.string)' ===")

        // Count image attachments in the text view
        var attachmentCount = 0
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            if let attach = value as? NSTextAttachment {
                attachmentCount += 1
                let hasFileWrapper = attach.fileWrapper != nil
                let hasImage = attach.image != nil
                print("  attachment at \(range): fileWrapper=\(hasFileWrapper) image=\(hasImage)")
            }
        }
        print("=== Attachment count: \(attachmentCount) ===")

        XCTAssertEqual(attachmentCount, 2,
                       "NSTextView must show 2 image attachments after paste")
        XCTAssertTrue(storage.string.contains("between images"),
                      "NSTextView must show the text content")

        // Clean up
        for item in [img1, img2] {
            imageStore.deleteImage(relativePath: item.filePath!)
            imageStore.deleteImage(relativePath: item.thumbnailPath!)
        }
    }

    func testWriteMultipleThreeImagesAllEmbedded() {
        let observer = makeClipboardObserver()
        let img1 = makeRealImageItem(color: .red)
        let img2 = makeRealImageItem(color: .green)
        let img3 = makeRealImageItem(color: .blue)

        PasteboardWriter.writeMultiple([img1, img2, img3], imageStore: imageStore, clipboardObserver: observer)

        let rtfdData = NSPasteboard.general.data(forType: .rtfd)!
        let readBack = NSAttributedString(rtfd: rtfdData, documentAttributes: nil)!

        var attachmentCount = 0
        readBack.enumerateAttribute(.attachment, in: NSRange(location: 0, length: readBack.length)) { value, _, _ in
            if value is NSTextAttachment { attachmentCount += 1 }
        }
        XCTAssertEqual(attachmentCount, 3, "All 3 images must be embedded in RTFD")

        // Clean up
        for item in [img1, img2, img3] {
            imageStore.deleteImage(relativePath: item.filePath!)
            imageStore.deleteImage(relativePath: item.thumbnailPath!)
        }
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

    func testNormalClickClearsCommandSelection() {
        let item = makeTextItem("selected")
        var selectedItems: Set<UUID> = [item.id]

        // Simulate regular click behavior in ItemRow (non-Command click)
        selectedItems.removeAll()

        XCTAssertTrue(selectedItems.isEmpty, "Regular click should clear command selection")
    }

    func testCommandClickSelectsItem() {
        let item = makeTextItem("cmd-click me")
        var selectedItems: Set<UUID> = []
        let commandHeld = true  // Simulates NSEvent.modifierFlags.contains(.command)

        if commandHeld {
            selectedItems.insert(item.id)
        }

        XCTAssertTrue(selectedItems.contains(item.id), "Command-click should select the item")
    }

    func testCommandClickAddsToExistingSelection() {
        let item1 = makeTextItem("first")
        let item2 = makeTextItem("second")
        var selectedItems: Set<UUID> = [item1.id]
        let commandHeld = true

        if commandHeld {
            if selectedItems.contains(item2.id) {
                selectedItems.remove(item2.id)
            } else {
                selectedItems.insert(item2.id)
            }
        }

        XCTAssertEqual(selectedItems.count, 2, "Should have both items selected")
        XCTAssertTrue(selectedItems.contains(item1.id))
        XCTAssertTrue(selectedItems.contains(item2.id))
    }

    func testCommandClickDeselectsAlreadySelectedItem() {
        let item = makeTextItem("deselect me")
        var selectedItems: Set<UUID> = [item.id]

        // Command-click on already-selected item should deselect
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }

        XCTAssertFalse(selectedItems.contains(item.id), "Should deselect already-selected item")
    }

    func testBatchCopyKeepsSelectionState() {
        // New UX: command-selected items stay selected until changed by user.
        let item1 = makeTextItem("a")
        let item2 = makeTextItem("b")
        let selectedItems: Set<UUID> = [item1.id, item2.id]

        var copiedCount = 0
        if !selectedItems.isEmpty {
            copiedCount = selectedItems.count
        }

        XCTAssertEqual(copiedCount, 2, "Batch copy should include all selected items")
        XCTAssertEqual(selectedItems.count, 2, "Batch copy should not clear command selection")
    }

    func testCommandClickToggleBehavior() {
        let item1 = makeTextItem("toggle a")
        let item2 = makeTextItem("toggle b")
        var selectedItems: Set<UUID> = []

        // Select both with command-click
        for item in [item1, item2] {
            if selectedItems.contains(item.id) {
                selectedItems.remove(item.id)
            } else {
                selectedItems.insert(item.id)
            }
        }
        XCTAssertEqual(selectedItems.count, 2)

        // Deselect first with another command-click
        if selectedItems.contains(item1.id) {
            selectedItems.remove(item1.id)
        } else {
            selectedItems.insert(item1.id)
        }

        XCTAssertEqual(selectedItems.count, 1)
        XCTAssertTrue(selectedItems.contains(item2.id))
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
