import XCTest
import AppKit
@testable import Copyhog

/// Tests for the appearance mode (System / Light / Dark) feature.
/// Validates UserDefaults persistence, NSAppearance mapping, and window application.
@MainActor
final class AppearanceTests: XCTestCase {

    private let key = "appearanceMode"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: key)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    // MARK: - Defaults & Persistence

    func testDefaultAppearanceModeIsZero() {
        let mode = UserDefaults.standard.integer(forKey: key)
        XCTAssertEqual(mode, 0, "Default appearance mode should be 0 (System)")
    }

    func testSetLightModePersists() {
        UserDefaults.standard.set(1, forKey: key)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: key), 1)
    }

    func testSetDarkModePersists() {
        UserDefaults.standard.set(2, forKey: key)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: key), 2)
    }

    func testSetSystemModePersists() {
        UserDefaults.standard.set(2, forKey: key)
        UserDefaults.standard.set(0, forKey: key)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: key), 0)
    }

    // MARK: - NSAppearance Mapping

    func testSystemModeReturnsNilAppearance() {
        let appearance = Self.nsAppearance(for: 0)
        XCTAssertNil(appearance, "System mode (0) should return nil to follow system")
    }

    func testLightModeReturnsAquaAppearance() {
        let appearance = Self.nsAppearance(for: 1)
        XCTAssertNotNil(appearance)
        XCTAssertEqual(appearance?.name, .aqua, "Light mode (1) should return aqua appearance")
    }

    func testDarkModeReturnsDarkAquaAppearance() {
        let appearance = Self.nsAppearance(for: 2)
        XCTAssertNotNil(appearance)
        XCTAssertEqual(appearance?.name, .darkAqua, "Dark mode (2) should return darkAqua appearance")
    }

    func testInvalidModeReturnsNilAppearance() {
        let appearance = Self.nsAppearance(for: 99)
        XCTAssertNil(appearance, "Invalid mode should fall back to nil (system)")
    }

    // MARK: - Window Appearance Application

    func testApplyDarkAppearanceToPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        let appearance = NSAppearance(named: .darkAqua)
        panel.appearance = appearance
        XCTAssertEqual(panel.appearance?.name, .darkAqua,
                       "Panel should accept darkAqua appearance")
    }

    func testApplyLightAppearanceToPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        let appearance = NSAppearance(named: .aqua)
        panel.appearance = appearance
        XCTAssertEqual(panel.appearance?.name, .aqua,
                       "Panel should accept aqua appearance")
    }

    func testApplyNilAppearanceToPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.appearance = nil
        XCTAssertNil(panel.appearance,
                     "Setting nil should clear override and follow system")
    }

    func testSwitchingModeUpdatesPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )

        // Light
        panel.appearance = Self.nsAppearance(for: 1)
        XCTAssertEqual(panel.appearance?.name, .aqua)

        // Dark
        panel.appearance = Self.nsAppearance(for: 2)
        XCTAssertEqual(panel.appearance?.name, .darkAqua)

        // System
        panel.appearance = Self.nsAppearance(for: 0)
        XCTAssertNil(panel.appearance)
    }

    // MARK: - Helper (mirrors CopyhogApp.nsAppearance)

    private static func nsAppearance(for mode: Int) -> NSAppearance? {
        switch mode {
        case 1: return NSAppearance(named: .aqua)
        case 2: return NSAppearance(named: .darkAqua)
        default: return nil
        }
    }
}
