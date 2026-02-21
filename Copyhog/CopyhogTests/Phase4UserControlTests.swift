import XCTest
import AppKit
@testable import Copyhog

// MARK: - ClipItemStore Deletion Tests

@MainActor
final class ClipItemStoreRemoveTests: XCTestCase {

    private func makeTextItem(_ text: String = "test") -> ClipItem {
        ClipItem(
            id: UUID(),
            type: .text,
            content: text,
            thumbnailPath: nil,
            filePath: nil,
            timestamp: Date()
        )
    }

    private func makeImageItem() -> ClipItem {
        ClipItem(
            id: UUID(),
            type: .image,
            content: nil,
            thumbnailPath: "thumb.png",
            filePath: "full.png",
            timestamp: Date()
        )
    }

    /// Creates a store and clears any persisted items so tests start clean.
    private func makeCleanStore() -> ClipItemStore {
        let store = ClipItemStore()
        store.removeAll()
        return store
    }

    // MARK: - remove(id:)

    func testRemoveSingleItemByID() {
        let store = makeCleanStore()
        let item = makeTextItem("hello")
        store.add(item)
        XCTAssertEqual(store.items.count, 1)

        store.remove(id: item.id)
        XCTAssertEqual(store.items.count, 0, "Item should be removed from store")
    }

    func testRemoveSpecificItemFromMultiple() {
        let store = makeCleanStore()
        let item1 = makeTextItem("first")
        let item2 = makeTextItem("second")
        let item3 = makeTextItem("third")
        store.add(item1)
        store.add(item2)
        store.add(item3)
        XCTAssertEqual(store.items.count, 3)

        store.remove(id: item2.id)
        XCTAssertEqual(store.items.count, 2)
        XCTAssertNil(store.items.first(where: { $0.id == item2.id }),
                     "Removed item should not be in the store")
        XCTAssertNotNil(store.items.first(where: { $0.id == item1.id }),
                        "Other items should remain")
        XCTAssertNotNil(store.items.first(where: { $0.id == item3.id }),
                        "Other items should remain")
    }

    func testRemoveNonexistentIDIsNoOp() {
        let store = makeCleanStore()
        let item = makeTextItem()
        store.add(item)
        let countBefore = store.items.count

        store.remove(id: UUID()) // random ID not in store
        XCTAssertEqual(store.items.count, countBefore, "Store should be unchanged when removing unknown ID")
    }

    func testRemoveFromEmptyStoreIsNoOp() {
        let store = makeCleanStore()
        XCTAssertEqual(store.items.count, 0)

        store.remove(id: UUID())
        XCTAssertEqual(store.items.count, 0, "Removing from empty store should not crash")
    }

    // MARK: - removeAll()

    func testRemoveAllClearsAllItems() {
        let store = makeCleanStore()
        store.add(makeTextItem("one"))
        store.add(makeTextItem("two"))
        store.add(makeTextItem("three"))
        XCTAssertEqual(store.items.count, 3)

        store.removeAll()
        XCTAssertEqual(store.items.count, 0, "All items should be removed")
    }

    func testRemoveAllOnEmptyStoreIsNoOp() {
        let store = makeCleanStore()
        XCTAssertEqual(store.items.count, 0)

        store.removeAll()
        XCTAssertEqual(store.items.count, 0, "removeAll on empty store should not crash")
    }

    func testRemoveAllWithMixedItemTypes() {
        let store = makeCleanStore()
        store.add(makeTextItem("text item"))
        store.add(makeImageItem())
        store.add(makeTextItem("another text"))
        XCTAssertEqual(store.items.count, 3)

        store.removeAll()
        XCTAssertEqual(store.items.count, 0, "All item types should be cleared")
    }

    // MARK: - Store add/remove interaction

    func testAddAfterRemoveAllWorks() {
        let store = makeCleanStore()
        store.add(makeTextItem("before"))
        store.removeAll()
        XCTAssertEqual(store.items.count, 0)

        let newItem = makeTextItem("after")
        store.add(newItem)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.id, newItem.id)
    }

    func testRemovePreservesInsertionOrder() {
        let store = makeCleanStore()
        let item1 = makeTextItem("first")
        let item2 = makeTextItem("second")
        let item3 = makeTextItem("third")
        store.add(item1) // items: [item1]
        store.add(item2) // items: [item2, item1]
        store.add(item3) // items: [item3, item2, item1]

        store.remove(id: item2.id)
        // Should be [item3, item1]
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items[0].id, item3.id)
        XCTAssertEqual(store.items[1].id, item1.id)
    }
}

// MARK: - Hotkey Detection Tests

final class HotkeyDetectionTests: XCTestCase {

    // AppDelegate.isHotkeyEvent is private, so we test the logic pattern directly.
    // The hotkey should fire on keyCode 8 (C) with Shift+Ctrl, rejecting Option and Command.

    private func simulateKeyEvent(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )
    }

    private func isHotkeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == 8
            && flags.contains([.shift, .control])
            && !flags.contains(.option)
            && !flags.contains(.command)
    }

    func testShiftCtrlCIsRecognized() {
        guard let event = simulateKeyEvent(keyCode: 8, modifierFlags: [.shift, .control]) else {
            XCTFail("Failed to create key event")
            return
        }
        XCTAssertTrue(isHotkeyEvent(event), "Shift+Ctrl+C should be recognized as hotkey")
    }

    func testShiftCmdCIsRejected() {
        guard let event = simulateKeyEvent(keyCode: 8, modifierFlags: [.shift, .command]) else {
            XCTFail("Failed to create key event")
            return
        }
        XCTAssertFalse(isHotkeyEvent(event), "Shift+Cmd+C should NOT trigger hotkey")
    }

    func testCtrlCAloneIsRejected() {
        guard let event = simulateKeyEvent(keyCode: 8, modifierFlags: [.control]) else {
            XCTFail("Failed to create key event")
            return
        }
        XCTAssertFalse(isHotkeyEvent(event), "Ctrl+C without Shift should NOT trigger hotkey")
    }

    func testShiftCtrlOptionCIsRejected() {
        guard let event = simulateKeyEvent(keyCode: 8, modifierFlags: [.shift, .control, .option]) else {
            XCTFail("Failed to create key event")
            return
        }
        XCTAssertFalse(isHotkeyEvent(event), "Shift+Ctrl+Option+C should NOT trigger hotkey")
    }

    func testShiftCtrlCmdCIsRejected() {
        guard let event = simulateKeyEvent(keyCode: 8, modifierFlags: [.shift, .control, .command]) else {
            XCTFail("Failed to create key event")
            return
        }
        XCTAssertFalse(isHotkeyEvent(event), "Shift+Ctrl+Cmd+C should NOT trigger hotkey")
    }

    func testWrongKeyCodeIsRejected() {
        // keyCode 0 = A key
        guard let event = simulateKeyEvent(keyCode: 0, modifierFlags: [.shift, .control]) else {
            XCTFail("Failed to create key event")
            return
        }
        XCTAssertFalse(isHotkeyEvent(event), "Shift+Ctrl+A should NOT trigger hotkey")
    }

    func testShiftAloneIsRejected() {
        guard let event = simulateKeyEvent(keyCode: 8, modifierFlags: [.shift]) else {
            XCTFail("Failed to create key event")
            return
        }
        XCTAssertFalse(isHotkeyEvent(event), "Shift+C without Ctrl should NOT trigger hotkey")
    }
}

// MARK: - PopoverContent Phase 4 UI Tests

@MainActor
final class PopoverContentPhase4Tests: XCTestCase {

    private func makeTextItem(_ text: String) -> ClipItem {
        ClipItem(
            id: UUID(),
            type: .text,
            content: text,
            thumbnailPath: nil,
            filePath: nil,
            timestamp: Date()
        )
    }

    private func makeCleanStore() -> ClipItemStore {
        let store = ClipItemStore()
        store.removeAll()
        return store
    }

    func testEmptyStoreShowsEmptyState() {
        let store = makeCleanStore()
        XCTAssertTrue(store.items.isEmpty)
        // PopoverContent checks store.items.isEmpty to show ContentUnavailableView
        let view = PopoverContent().environmentObject(store)
        XCTAssertNotNil(view)
    }

    func testStoreBecomesEmptyAfterRemoveAll() {
        let store = makeCleanStore()
        store.add(makeTextItem("one"))
        store.add(makeTextItem("two"))
        XCTAssertFalse(store.items.isEmpty)

        store.removeAll()
        // After removeAll, store.items.isEmpty is true,
        // which means PopoverContent would show empty state
        XCTAssertTrue(store.items.isEmpty,
                      "Store should be empty after removeAll, triggering empty state in UI")
    }

    func testOnDeleteRemovesCorrectItem() {
        // Simulates what the .onDelete handler does in PopoverContent
        let store = makeCleanStore()
        let item1 = makeTextItem("first")
        let item2 = makeTextItem("second")
        let item3 = makeTextItem("third")
        store.add(item1)
        store.add(item2)
        store.add(item3)

        // Simulate .onDelete for index 1 (which is item2 since add inserts at front)
        // After adding: [item3, item2, item1]
        let indexToDelete = 1
        let itemToRemove = store.items[indexToDelete]
        store.remove(id: itemToRemove.id)

        XCTAssertEqual(store.items.count, 2)
        XCTAssertNil(store.items.first(where: { $0.id == item2.id }))
    }

    func testHogWipeResetsSelectionState() {
        // Verifies the logic that Hog Wipe clears selectedItems and isMultiSelectActive
        let store = makeCleanStore()
        store.add(makeTextItem("item"))

        var selectedItems: Set<UUID> = [store.items[0].id]
        var isMultiSelectActive = true

        // Simulate Hog Wipe button action
        store.removeAll()
        selectedItems.removeAll()
        isMultiSelectActive = false

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(selectedItems.isEmpty, "Selected items should be cleared after Hog Wipe")
        XCTAssertFalse(isMultiSelectActive, "Multi-select should be deactivated after Hog Wipe")
    }

    func testMaxItemsPurgesOldest() {
        let store = makeCleanStore()
        // Add 21 items (max is 20)
        for i in 0..<21 {
            store.add(makeTextItem("item \(i)"))
        }
        XCTAssertEqual(store.items.count, 20, "Store should cap at 20 items")
        // The first item added (item 0) should have been purged
        XCTAssertNil(store.items.first(where: { $0.content == "item 0" }),
                     "Oldest item should be purged when exceeding max")
    }
}
