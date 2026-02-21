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
    func applicationDidFinishLaunching(_ notification: Notification) {
        registerLaunchAtLogin()
        startCaptureServices()
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

    func applicationWillTerminate(_ notification: Notification) {
        clipboardObserver?.stop()
        screenshotWatcher?.stop()
    }
}
