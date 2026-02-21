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
                .environmentObject(appDelegate.exclusionManager)
                .frame(width: 400, height: 520)
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
    let exclusionManager = ExclusionManager()
    let bookmarkManager = BookmarkManager()
    private var clipboardObserver: ClipboardObserver?
    private var screenshotWatcher: ScreenshotWatcher?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerLaunchAtLogin()
        startClipboardCapture()
        startScreenshotCaptureIfReady()
    }

    // MARK: - Clipboard Capture (always runs)

    private func startClipboardCapture() {
        let observer = ClipboardObserver(imageStore: store.imageStore)
        observer.exclusionManager = exclusionManager
        observer.start { [weak store] item in
            store?.add(item)
        }
        clipboardObserver = observer
        store.clipboardObserver = observer
    }

    // MARK: - Screenshot Capture (requires bookmarks)

    private func startScreenshotCaptureIfReady() {
        if bookmarkManager.hasCompletedSetup {
            launchScreenshotWatcher()
        } else {
            showOnboarding()
        }
    }

    private func launchScreenshotWatcher() {
        guard let observer = clipboardObserver else { return }
        let watcher = ScreenshotWatcher(bookmarkManager: bookmarkManager)
        watcher.start(
            clipboardObserver: observer,
            imageStore: store.imageStore,
            onNewItem: { [weak store] item in
                store?.add(item)
            }
        )
        screenshotWatcher = watcher
    }

    private func showOnboarding() {
        let view = OnboardingView(
            bookmarkManager: bookmarkManager,
            onComplete: { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
                self?.launchScreenshotWatcher()
            },
            onSkip: { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Copyhog Setup"
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func registerLaunchAtLogin() {
        try? SMAppService.mainApp.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardObserver?.stop()
        screenshotWatcher?.stop()
        bookmarkManager.stopAccessingAll()
    }
}
