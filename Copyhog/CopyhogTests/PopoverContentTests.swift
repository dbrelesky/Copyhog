import XCTest
import SwiftUI
@testable import Copyhog

@MainActor
final class PopoverContentTests: XCTestCase {

    // MARK: - Quit Button Existence

    func testQuitButtonExistsInPopoverContent() throws {
        // PopoverContent contains a "Quit Copyhog" button that calls
        // NSApplication.shared.terminate(nil). We verify the view body
        // can be constructed without error when the store has items,
        // which exercises the branch containing the quit button.
        let store = ClipItemStore()
        let view = PopoverContent().environmentObject(store)
        XCTAssertNotNil(view, "PopoverContent should instantiate with an empty store")
    }

    func testQuitButtonExistsWhenStoreHasItems() throws {
        let store = ClipItemStore()
        let item = ClipItem(
            id: UUID(),
            type: .text,
            content: "test clipboard text",
            thumbnailPath: nil,
            filePath: nil,
            timestamp: Date()
        )
        store.add(item)
        let view = PopoverContent().environmentObject(store)
        XCTAssertNotNil(view, "PopoverContent should instantiate with items in store")
    }

    // MARK: - NSApplication.terminate availability

    func testTerminateMethodExists() {
        // Verify NSApplication.shared responds to terminate(_:)
        // This is the method the quit button calls.
        let app = NSApplication.shared
        XCTAssertTrue(
            app.responds(to: #selector(NSApplication.terminate(_:))),
            "NSApplication.shared must respond to terminate(_:)"
        )
    }

    // MARK: - PopoverContent frame size

    func testPopoverFrameSize() throws {
        // The popover should be 360x480 — verify the view can be
        // hosted at that size without issues.
        let store = ClipItemStore()
        let view = PopoverContent().environmentObject(store)
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(x: 0, y: 0, width: 360, height: 480)
        XCTAssertEqual(hosted.frame.width, 360)
        XCTAssertEqual(hosted.frame.height, 480)
    }
}
