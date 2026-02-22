import AppKit
import Foundation

@MainActor
final class PlainPasteService {

    private nonisolated(unsafe) var monitor: Any?
    private let clipboardObserver: ClipboardObserver

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "plainPasteEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "plainPasteEnabled")
            if newValue { startMonitor() } else { stopMonitor() }
        }
    }

    init(clipboardObserver: ClipboardObserver) {
        self.clipboardObserver = clipboardObserver

        // Register default (enabled by default)
        UserDefaults.standard.register(defaults: ["plainPasteEnabled": true])

        if isEnabled {
            startMonitor()
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Private

    private func startMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Cmd+Shift+V: keyCode 9 = 'v'
            let requiredFlags: NSEvent.ModifierFlags = [.command, .shift]
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.contains(requiredFlags), event.keyCode == 9 else { return }

            MainActor.assumeIsolated {
                self?.stripPasteboardToPlainText()
            }
        }
    }

    private func stopMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func stripPasteboardToPlainText() {
        let pasteboard = NSPasteboard.general
        guard let plainText = pasteboard.string(forType: .string), !plainText.isEmpty else { return }

        clipboardObserver.skipNextChange()
        pasteboard.clearContents()
        pasteboard.setString(plainText, forType: .string)
    }
}
