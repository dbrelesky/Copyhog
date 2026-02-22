import AppKit
import Foundation
@preconcurrency import ApplicationServices

@MainActor
struct AutoPasteService {

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "autoPasteEnabled") as? Bool ?? false
    }

    /// Dismisses the popover, waits for the target app to regain focus,
    /// then simulates Cmd+V to paste.
    static func pasteAfterDismiss() {
        guard isEnabled else { return }

        // Close the popover panel
        for window in NSApp.windows where window is NSPanel {
            window.close()
        }

        // Short delay for the target app to regain focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            simulateCmdV()
        }
    }

    private static func simulateCmdV() {
        // Ensure we have accessibility permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        guard trusted else { return }

        let source = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)

        // keyCode 9 = 'v'
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return
        }

        keyDown.flags = CGEventFlags.maskCommand
        keyUp.flags = CGEventFlags.maskCommand

        keyDown.post(tap: CGEventTapLocation.cghidEventTap)
        keyUp.post(tap: CGEventTapLocation.cghidEventTap)
    }
}
