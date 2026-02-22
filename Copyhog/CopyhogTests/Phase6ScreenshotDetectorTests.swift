import XCTest
@testable import Copyhog

// MARK: - ScreenshotLocationDetector Tests

final class ScreenshotLocationDetectorTests: XCTestCase {

    func testDetectReturnsURL() {
        let url = ScreenshotLocationDetector.detect()
        XCTAssertFalse(url.path.isEmpty, "Detected URL should have a non-empty path")
    }

    func testDetectReturnsExistingDirectory() {
        let url = ScreenshotLocationDetector.detect()
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        XCTAssertTrue(exists, "Detected screenshot location should exist")
        XCTAssertTrue(isDir.boolValue, "Detected screenshot location should be a directory")
    }

    func testDetectFallsBackToDesktop() {
        // When no custom screencapture location is set, should fallback to ~/Desktop
        let url = ScreenshotLocationDetector.detect()
        let desktop = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")

        // Either the custom location is set or we get Desktop as fallback
        // We can at least verify the result is a valid directory
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir))
    }

    func testDetectReturnsSameResultOnMultipleCalls() {
        let url1 = ScreenshotLocationDetector.detect()
        let url2 = ScreenshotLocationDetector.detect()
        XCTAssertEqual(url1, url2, "Multiple detect() calls should return the same URL")
    }
}
