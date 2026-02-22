import SwiftUI
import AppKit
import ServiceManagement

@main
struct CopyhogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("appearanceMode") private var appearanceMode = 0

    private var nsAppearance: NSAppearance? {
        switch appearanceMode {
        case 1: return NSAppearance(named: .aqua)
        case 2: return NSAppearance(named: .darkAqua)
        default: return nil
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverContent()
                .environmentObject(appDelegate.store)
                .environmentObject(appDelegate.exclusionManager)
                .frame(width: 400, height: 520)
                .onAppear { applyAppearance() }
                .onChange(of: appearanceMode) { _, _ in applyAppearance() }
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

    private func applyAppearance() {
        let appearance = nsAppearance
        for window in NSApp.windows where window is NSPanel {
            window.appearance = appearance
        }
    }
}

extension Notification.Name {
    static let showScreenshotSetup = Notification.Name("showScreenshotSetup")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let store = ClipItemStore()
    let exclusionManager = ExclusionManager()
    let bookmarkManager = BookmarkManager()
    private var clipboardObserver: ClipboardObserver?
    private var screenshotWatcher: ScreenshotWatcher?
    private var plainPasteService: PlainPasteService?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        syncLaunchAtLogin()
        startClipboardCapture()
        startScreenshotCaptureIfReady()

        NotificationCenter.default.addObserver(
            forName: .showScreenshotSetup,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.showOnboarding()
            }
        }
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
        plainPasteService = PlainPasteService(clipboardObserver: observer)
    }

    // MARK: - Screenshot Capture (requires bookmarks)

    private func startScreenshotCaptureIfReady() {
        if bookmarkManager.hasCompletedSetup {
            launchScreenshotWatcher()
        } else {
            showOnboarding()
        }
    }

    func launchScreenshotWatcher() {
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

    func showOnboarding() {
        // If already showing, just bring it forward
        if let existing = onboardingWindow, existing.isVisible {
            existing.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Dismiss the MenuBarExtra popover so it doesn't cover the setup window
        for window in NSApp.windows where window is NSPanel {
            window.close()
        }

        // Stop existing watcher so we can re-setup
        screenshotWatcher?.stop()
        screenshotWatcher = nil

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
        window.level = .floating
        onboardingWindow = window
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func syncLaunchAtLogin() {
        if UserDefaults.standard.bool(forKey: "launchAtLogin") {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.flushSave()
        clipboardObserver?.stop()
        screenshotWatcher?.stop()
        bookmarkManager.stopAccessingAll()
    }
}
