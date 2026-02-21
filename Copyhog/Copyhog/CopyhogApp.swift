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
    private var statusButton: NSStatusBarButton?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerLaunchAtLogin()
        requestAccessibilityPermission()
        registerGlobalHotkey()
        startCaptureServices()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.statusButton = NSApp.windows
                .compactMap({ $0.value(forKey: "statusItem") as? NSStatusItem })
                .first?.button
        }
    }

    private func startCaptureServices() {
        let observer = ClipboardObserver(imageStore: store.imageStore)
        observer.start { [weak store] item in
            store?.add(item)
        }
        clipboardObserver = observer
        store.clipboardObserver = observer

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
            guard let self, self.isHotkeyEvent(event) else { return }
            DispatchQueue.main.async {
                self.togglePopover()
            }
        }

        // Monitor events when Copyhog is frontmost
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.isHotkeyEvent(event) {
                DispatchQueue.main.async {
                    self.togglePopover()
                }
                return nil // Consume the event
            }
            return event
        }
    }

    private nonisolated func isHotkeyEvent(_ event: NSEvent) -> Bool {
        // Shift + Command + C (keyCode 8)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == 8
            && flags.contains([.shift, .command])
            && !flags.contains(.option)
            && !flags.contains(.control)
    }

    private func togglePopover() {
        if statusButton == nil {
            statusButton = NSApp.windows
                .compactMap({ $0.value(forKey: "statusItem") as? NSStatusItem })
                .first?.button
        }
        guard let button = statusButton else { return }
        NSApp.activate(ignoringOtherApps: true)
        button.performClick(nil)
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
