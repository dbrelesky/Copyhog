import SwiftUI
import AppKit
import ServiceManagement

@main
struct CopyhogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            PopoverContent()
                .environmentObject(appDelegate.store)
                .frame(width: 360, height: 480)
        } label: {
            if let image = NSImage(named: "MenuBarIcon") {
                let ratio = image.size.height / image.size.width
                let _ = {
                    image.size.height = 18
                    image.size.width = 18 / ratio
                    image.isTemplate = true
                }()
                Image(nsImage: image)
            } else {
                Image(systemName: "circle.fill")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let store = ClipItemStore()
    private var clipboardObserver: ClipboardObserver?
    private var screenshotWatcher: ScreenshotWatcher?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerLaunchAtLogin()
        requestAccessibilityPermission()
        registerGlobalHotkey()
        startCaptureServices()
    }

    private func startCaptureServices() {
        let observer = ClipboardObserver(imageStore: store.imageStore)
        observer.start { [weak store] item in
            store?.add(item)
        }
        clipboardObserver = observer

        let watcher = ScreenshotWatcher()
        watcher.start(
            clipboardObserver: observer,
            imageStore: store.imageStore,
            onNewItem: { [weak store] item in
                store?.add(item)
            }
        )
        screenshotWatcher = watcher
    }

    private func registerLaunchAtLogin() {
        try? SMAppService.mainApp.register()
    }

    private func requestAccessibilityPermission() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func registerGlobalHotkey() {
        // Monitor events when other apps are frontmost
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            if self.isHotkeyEvent(event) {
                MainActor.assumeIsolated {
                    self.togglePopover()
                }
            }
        }

        // Monitor events when Copyhog is frontmost
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.isHotkeyEvent(event) {
                MainActor.assumeIsolated {
                    self.togglePopover()
                }
                return nil // Consume the event
            }
            return event
        }
    }

    private nonisolated func isHotkeyEvent(_ event: NSEvent) -> Bool {
        // Shift + Up Arrow (keyCode 126)
        // Check that ONLY shift is pressed (not shift+cmd, shift+opt, etc.)
        let shiftOnly = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .shift
        return shiftOnly && event.keyCode == 126
    }

    private func togglePopover() {
        // MenuBarExtra with .window style creates an NSPanel attached to an NSStatusItem.
        // Find the status button and simulate a click to toggle the popover.
        if let button = NSApp.windows
            .compactMap({ $0.value(forKey: "statusItem") as? NSStatusItem })
            .first?.button {
            button.performClick(nil)
        }
    }

    func removeMonitors() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeMonitors()
        clipboardObserver?.stop()
        screenshotWatcher?.stop()
    }
}
