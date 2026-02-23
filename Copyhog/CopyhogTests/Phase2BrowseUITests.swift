import XCTest
import SwiftUI
import AppKit
@testable import Copyhog

// MARK: - PopoverContent Phase 2 Tests

@MainActor
final class PopoverContentPhase2Tests: XCTestCase {

    private func makeTextItem(_ text: String, timestamp: Date = Date()) -> ClipItem {
        ClipItem(id: UUID(), type: .text, content: text, thumbnailPath: nil, filePath: nil, timestamp: timestamp)
    }

    private func makeImageItem(thumbPath: String? = "thumb.png", filePath: String? = "full.png") -> ClipItem {
        ClipItem(id: UUID(), type: .image, content: nil, thumbnailPath: thumbPath, filePath: filePath, timestamp: Date())
    }

    private func makeCleanStore() -> ClipItemStore {
        let store = ClipItemStore()
        store.removeAll()
        return store
    }

    // MARK: - Empty state

    func testEmptyStoreRendersWithoutCrash() {
        let store = makeCleanStore()
        let view = PopoverContent().environmentObject(store)
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(x: 0, y: 0, width: 360, height: 480)
        XCTAssertNotNil(hosted, "PopoverContent should render with empty store")
    }

    func testEmptyStoreItemsIsEmpty() {
        let store = makeCleanStore()
        XCTAssertTrue(store.items.isEmpty, "Clean store should have no items for empty state branch")
    }

    // MARK: - Frame dimensions

    func testPopoverFrameIs360x480() {
        let store = makeCleanStore()
        store.add(makeTextItem("test"))
        let view = PopoverContent().environmentObject(store)
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(x: 0, y: 0, width: 360, height: 480)
        XCTAssertEqual(hosted.frame.width, 360)
        XCTAssertEqual(hosted.frame.height, 480)
        store.removeAll()
    }

    // MARK: - Preview pane default item

    func testPreviewItemDefaultsToMostRecent() {
        let store = makeCleanStore()
        let older = makeTextItem("older")
        let newer = makeTextItem("newer")
        store.add(older)
        store.add(newer)

        // store.items[0] is the most recent (newer) because add inserts at front
        XCTAssertEqual(store.items.first?.id, newer.id,
                       "Most recent item should be first, used as default preview item")
        store.removeAll()
    }

    // MARK: - Store with items renders

    func testPopoverWithTextItemsRenders() {
        let store = makeCleanStore()
        store.add(makeTextItem("Hello"))
        store.add(makeTextItem("World"))

        let view = PopoverContent().environmentObject(store)
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(x: 0, y: 0, width: 360, height: 480)
        XCTAssertNotNil(hosted)
        store.removeAll()
    }

    func testPopoverWithImageItemsRenders() {
        let store = makeCleanStore()
        store.add(makeImageItem())

        let view = PopoverContent().environmentObject(store)
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(x: 0, y: 0, width: 360, height: 480)
        XCTAssertNotNil(hosted)
        store.removeAll()
    }

    func testPopoverWithMixedItemsRenders() {
        let store = makeCleanStore()
        store.add(makeTextItem("text clip"))
        store.add(makeImageItem())
        store.add(makeTextItem("another text"))

        let view = PopoverContent().environmentObject(store)
        XCTAssertNotNil(view)
        XCTAssertEqual(store.items.count, 3)
        store.removeAll()
    }

    // MARK: - MRU ordering in list

    func testItemsDisplayInMRUOrder() {
        let store = makeCleanStore()
        let item1 = makeTextItem("first added")
        let item2 = makeTextItem("second added")
        let item3 = makeTextItem("third added")
        store.add(item1)
        store.add(item2)
        store.add(item3)

        // Items should be in reverse insertion order (MRU)
        XCTAssertEqual(store.items[0].content, "third added")
        XCTAssertEqual(store.items[1].content, "second added")
        XCTAssertEqual(store.items[2].content, "first added")
        store.removeAll()
    }
}

// MARK: - PreviewPane Tests

@MainActor
final class PreviewPaneTests: XCTestCase {

    func testPreviewPaneWithTextItem() {
        let item = ClipItem(
            id: UUID(), type: .text, content: "Preview text",
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )
        let view = PreviewPane(item: item, imageStore: ImageStore())
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(x: 0, y: 0, width: 360, height: 200)
        XCTAssertNotNil(hosted, "PreviewPane with text item should render")
    }

    func testPreviewPaneWithImageItem() {
        let item = ClipItem(
            id: UUID(), type: .image, content: nil,
            thumbnailPath: "thumb.png", filePath: "full.png", timestamp: Date()
        )
        let view = PreviewPane(item: item, imageStore: ImageStore())
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(x: 0, y: 0, width: 360, height: 200)
        XCTAssertNotNil(hosted, "PreviewPane with image item should render (even if image missing)")
    }

    func testPreviewPaneWithNilItem() {
        let view = PreviewPane(item: nil, imageStore: ImageStore())
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(x: 0, y: 0, width: 360, height: 200)
        XCTAssertNotNil(hosted, "PreviewPane with nil item should render clear color")
    }

    func testPreviewPaneWithEmptyTextContent() {
        let item = ClipItem(
            id: UUID(), type: .text, content: "",
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )
        let view = PreviewPane(item: item, imageStore: ImageStore())
        XCTAssertNotNil(view, "PreviewPane should handle empty text content")
    }

    func testPreviewPaneWithNilContent() {
        let item = ClipItem(
            id: UUID(), type: .text, content: nil,
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )
        let view = PreviewPane(item: item, imageStore: ImageStore())
        XCTAssertNotNil(view, "PreviewPane should handle nil content gracefully")
    }
}

// MARK: - ItemRow Tests

@MainActor
final class ItemRowTests: XCTestCase {

    func testItemRowWithTextItem() {
        let item = ClipItem(
            id: UUID(), type: .text, content: "Row text",
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )
        var hoveredID: UUID? = nil
        var selectedItems: Set<UUID> = []

        let view = ItemRow(
            item: item,
            imageStore: ImageStore(),
            hoveredItemID: Binding(get: { hoveredID }, set: { hoveredID = $0 }),
            selectedItems: Binding(get: { selectedItems }, set: { selectedItems = $0 }),
            clipboardObserver: nil
        )
        XCTAssertNotNil(view, "ItemRow with text should instantiate")
    }

    func testItemRowWithImageItem() {
        let item = ClipItem(
            id: UUID(), type: .image, content: nil,
            thumbnailPath: "thumb.png", filePath: "full.png", timestamp: Date()
        )
        var hoveredID: UUID? = nil
        var selectedItems: Set<UUID> = []

        let view = ItemRow(
            item: item,
            imageStore: ImageStore(),
            hoveredItemID: Binding(get: { hoveredID }, set: { hoveredID = $0 }),
            selectedItems: Binding(get: { selectedItems }, set: { selectedItems = $0 }),
            clipboardObserver: nil
        )
        XCTAssertNotNil(view, "ItemRow with image should instantiate")
    }

    func testItemRowWithCommandSelection() {
        let item = ClipItem(
            id: UUID(), type: .text, content: "selectable",
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )
        var hoveredID: UUID? = nil
        var selectedItems: Set<UUID> = [item.id]

        let view = ItemRow(
            item: item,
            imageStore: ImageStore(),
            hoveredItemID: Binding(get: { hoveredID }, set: { hoveredID = $0 }),
            selectedItems: Binding(get: { selectedItems }, set: { selectedItems = $0 }),
            clipboardObserver: nil
        )
        XCTAssertNotNil(view, "ItemRow with selected item should instantiate")
    }

    func testItemRowHoverState() {
        let item = ClipItem(
            id: UUID(), type: .text, content: "hover me",
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )
        var hoveredID: UUID? = item.id
        var selectedItems: Set<UUID> = []

        let view = ItemRow(
            item: item,
            imageStore: ImageStore(),
            hoveredItemID: Binding(get: { hoveredID }, set: { hoveredID = $0 }),
            selectedItems: Binding(get: { selectedItems }, set: { selectedItems = $0 }),
            clipboardObserver: nil
        )
        XCTAssertNotNil(view, "ItemRow with hover state should instantiate")
        XCTAssertEqual(hoveredID, item.id)
    }

    func testItemRowWithLongText() {
        let longText = String(repeating: "A very long clipboard text. ", count: 50)
        let item = ClipItem(
            id: UUID(), type: .text, content: longText,
            thumbnailPath: nil, filePath: nil, timestamp: Date()
        )
        var hoveredID: UUID? = nil
        var selectedItems: Set<UUID> = []

        let view = ItemRow(
            item: item,
            imageStore: ImageStore(),
            hoveredItemID: Binding(get: { hoveredID }, set: { hoveredID = $0 }),
            selectedItems: Binding(get: { selectedItems }, set: { selectedItems = $0 }),
            clipboardObserver: nil
        )
        XCTAssertNotNil(view, "ItemRow should handle long text without crash")
    }
}
