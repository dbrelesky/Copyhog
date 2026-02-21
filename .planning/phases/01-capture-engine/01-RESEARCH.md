# Phase 1: Capture Engine - Research

**Researched:** 2026-02-20
**Domain:** Native macOS menu bar app — Swift 6.2 / SwiftUI / AppKit interop
**Confidence:** HIGH

## Summary

Phase 1 builds the invisible engine: a menu bar shell with an empty popover, clipboard polling, screenshot directory watching, and a persistent item store capped at 20 entries. The entire phase is native Swift/SwiftUI targeting macOS, using `MenuBarExtra` with `.window` style for the popover, `NSPasteboard.general.changeCount` polling on a 0.5s timer for clipboard capture, `DispatchSource.makeFileSystemObjectSource` for screenshot directory monitoring, and `Codable` JSON file persistence for the item store.

The development environment has Swift 6.2.3 and Xcode 26.2 available. The project will be structured as an Xcode project (not SPM-only) because macOS menu bar apps require an Info.plist with `LSUIElement = YES`, an asset catalog for the template icon, entitlements for accessibility, and proper .app bundle structure that SPM alone cannot produce.

**Primary recommendation:** Use `MenuBarExtra` with `.window` style and `.frame(width: 360, height: 480)` on the content view for the shell, a `Timer.scheduledTimer` polling `NSPasteboard.general.changeCount` every 0.5s for clipboard capture, `DispatchSource.makeFileSystemObjectSource` with `.write` event mask for screenshot watching, and a JSON file in Application Support for persistence.

## Standard Stack

### Core
| Library / API | Version | Purpose | Why Standard |
|---------------|---------|---------|--------------|
| Swift | 6.2.3 | Language | Available on dev machine, latest stable |
| SwiftUI | macOS 14+ | App shell, MenuBarExtra, popover UI | `MenuBarExtra` with `.window` style is the modern standard for menu bar popovers |
| AppKit (NSPasteboard, NSEvent, NSImage) | macOS 14+ | Clipboard access, image handling | No SwiftUI equivalent for clipboard polling |
| Dispatch (GCD) | System | Timer, DispatchSource for file watching | Built-in, no external dependency needed |
| ServiceManagement (SMAppService) | macOS 13+ | Launch at login | Modern replacement for deprecated login item APIs |
| Foundation (FileManager, JSONEncoder/Decoder) | System | File operations, JSON persistence | Standard for file I/O and Codable serialization |

### Supporting
| Library / API | Version | Purpose | When to Use |
|---------------|---------|---------|-------------|
| Combine | System | Reactive data flow between store and UI | Optional — `@Published` properties on ObservableObject for store updates |
| OSLog | System | Structured logging | Debug clipboard/screenshot events during development |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| DispatchSource file watching | FSEvents (CoreServices) | FSEvents monitors entire directory hierarchies; DispatchSource is cheaper for single-directory top-level monitoring — use DispatchSource |
| JSON file persistence | UserDefaults with Codable | UserDefaults has ~512KB soft limit and is meant for preferences, not structured data with images; JSON file in App Support is more appropriate |
| JSON file persistence | SwiftData / Core Data | Overkill for 20 items; adds framework complexity without benefit at this scale |

**Installation:**
No external packages required. All APIs are system frameworks.

## Architecture Patterns

### Recommended Project Structure
```
Copyhog/
├── Copyhog.xcodeproj
├── Copyhog/
│   ├── CopyhogApp.swift           # @main, MenuBarExtra scene
│   ├── Info.plist                  # LSUIElement = YES
│   ├── Copyhog.entitlements        # App Sandbox OFF (for NSEvent monitoring)
│   ├── Assets.xcassets/
│   │   └── MenuBarIcon.imageset/   # 16px hedgehog silhouette template image
│   ├── Models/
│   │   └── ClipItem.swift          # Codable model: id, type, content, thumbnail, filePath, timestamp
│   ├── Services/
│   │   ├── ClipboardObserver.swift # Timer + NSPasteboard.changeCount polling
│   │   ├── ScreenshotWatcher.swift # DispatchSource directory monitoring
│   │   └── ImageStore.swift        # Save/load images to App Support
│   ├── Store/
│   │   └── ClipItemStore.swift     # @Published items array, JSON persistence, 20-item cap
│   └── Views/
│       └── PopoverContent.swift    # Empty placeholder for Phase 1
```

### Pattern 1: MenuBarExtra with Window Style
**What:** SwiftUI scene that creates a persistent menu bar icon with a popover window
**When to use:** Any menu bar utility that needs custom UI (not just a dropdown menu)
**Example:**
```swift
// Source: Apple docs + nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/
@main
struct CopyhogApp: App {
    @StateObject private var store = ClipItemStore()

    var body: some Scene {
        MenuBarExtra {
            PopoverContent()
                .environmentObject(store)
                .frame(width: 360, height: 480)
        } label: {
            let image: NSImage = {
                let ratio = $0.size.height / $0.size.width
                $0.size.height = 18
                $0.size.width = 18 / ratio
                return $0
            }(NSImage(named: "MenuBarIcon")!)
            Image(nsImage: image)
        }
        .menuBarExtraStyle(.window)
    }
}
```

### Pattern 2: Clipboard Polling with Change Count
**What:** Timer fires every 0.5s, compares `NSPasteboard.general.changeCount` to detect new copies
**When to use:** Any macOS clipboard monitoring (NSPasteboard has no notification API)
**Example:**
```swift
// Source: Maccy Clipboard.swift pattern + Apple NSPasteboard docs
class ClipboardObserver: ObservableObject {
    private var timer: Timer?
    private var lastChangeCount: Int
    private let pasteboard = NSPasteboard.general

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    func start(onNewItem: @escaping (ClipItem) -> Void) {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let currentCount = self.pasteboard.changeCount
            guard currentCount != self.lastChangeCount else { return }
            self.lastChangeCount = currentCount

            // Read text
            if let string = self.pasteboard.string(forType: .string) {
                onNewItem(ClipItem(type: .text, content: string))
            }
            // Read image
            else if let data = self.pasteboard.data(forType: .tiff),
                    let image = NSImage(data: data) {
                onNewItem(ClipItem(type: .image, imageData: data))
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
```

### Pattern 3: Directory Monitoring with DispatchSource
**What:** Watch a directory for new files using GCD dispatch source
**When to use:** Detecting new screenshots or file additions without polling
**Example:**
```swift
// Source: swiftrocks.com/dispatchsource-detecting-changes-in-files-and-folders-in-swift
class ScreenshotWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    func startWatching(directory: URL, onChange: @escaping () -> Void) {
        fileDescriptor = open(directory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: .main
        )

        source?.setEventHandler {
            onChange()  // Directory contents changed — enumerate for new .png files
        }

        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
        }

        source?.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}
```

### Anti-Patterns to Avoid
- **Polling the file system for screenshots:** Use DispatchSource, not a timer scanning directory contents
- **Storing images in UserDefaults:** Binary data bloats the plist; store image files on disk, keep only file paths in the model
- **Using NSPasteboard notifications:** They don't exist on macOS — you must poll changeCount
- **Ignoring own clipboard writes:** When the app writes to the clipboard (e.g., copying a screenshot), the changeCount increments — you must track and skip your own writes to avoid infinite capture loops
- **Sandbox entitlement with NSEvent monitoring:** `NSEvent.addGlobalMonitorForEvents` requires App Sandbox to be OFF, or Input Monitoring permission

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Launch at login | Custom LaunchAgent plist | `SMAppService.mainApp.register()` | Modern API, handles edge cases, survives app updates |
| Image thumbnail generation | Manual pixel resizing | `NSImage` with `draw(in:from:operation:fraction:)` to target size | Handles color spaces, retina, orientation correctly |
| JSON file persistence | Custom binary format | `JSONEncoder`/`JSONDecoder` with `Codable` | Debuggable, human-readable, no migration complexity for 20 items |
| Screenshot directory detection | Hardcoded `~/Desktop` | `defaults read com.apple.screencapture location` fallback to `~/Desktop` | Users can change screenshot location via Screenshot.app or defaults |
| App Support directory path | Hardcoded path string | `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` | Correct across user accounts, follows Apple conventions |

**Key insight:** macOS has well-defined APIs for every system interaction in this phase. The only "custom" code is the glue: wiring the clipboard observer and screenshot watcher to the item store.

## Common Pitfalls

### Pitfall 1: Infinite Clipboard Capture Loop
**What goes wrong:** App copies a screenshot to the clipboard (SCRN-03), which triggers the clipboard observer (CLIP-01/02), which captures it again as a new item, which may trigger another write.
**Why it happens:** `NSPasteboard.general.changeCount` increments on every write, including the app's own writes.
**How to avoid:** Set a flag (`isOwnWrite = true`) before writing to the pasteboard, and check it in the clipboard observer. Clear the flag after the changeCount is noted. Alternatively, save the changeCount immediately after your own write so the next poll sees no change.
**Warning signs:** Duplicate items appearing in the store for every screenshot capture.

### Pitfall 2: Screenshot File Not Ready When Detected
**What goes wrong:** DispatchSource fires `.write` event while macOS is still writing the screenshot file. Reading the file immediately yields incomplete data or fails.
**Why it happens:** The file system event fires on directory modification, not file completion. macOS writes screenshots progressively.
**How to avoid:** After detecting a new file, wait briefly (0.3-0.5s) and verify the file size is stable before processing. Alternatively, check if the file is locked using `fcntl` or retry with exponential backoff.
**Warning signs:** Corrupted or truncated screenshot images in the store.

### Pitfall 3: Screenshot Directory Varies Per User
**What goes wrong:** Hardcoding `~/Desktop` as the screenshot source misses screenshots for users who changed their location.
**Why it happens:** macOS allows changing the screenshot directory via Screenshot.app (Options menu) or `defaults write com.apple.screencapture location`.
**How to avoid:** Read `defaults read com.apple.screencapture location` at startup. Fall back to `~/Desktop` if the key doesn't exist. Verified on dev machine: key does not exist by default, confirming Desktop is the default location.
**Warning signs:** App reports "no screenshots detected" while user is actively taking screenshots.

### Pitfall 4: MenuBarExtra Window Style Sizing
**What goes wrong:** The popover window doesn't respect the expected 360x480 size, appearing too small or using default sizing.
**Why it happens:** `MenuBarExtra` with `.window` style sizes based on content intrinsic size, which may not match `.frame()` if content is empty or uses flexible layouts.
**How to avoid:** Apply `.frame(width: 360, height: 480)` directly on the root content view inside the MenuBarExtra closure. For Phase 1 (empty popover), use a `Color.clear.frame(width: 360, height: 480)` or `Spacer().frame(width: 360, height: 480)` to enforce size.
**Warning signs:** Popover appears as a tiny window or collapses to zero size.

### Pitfall 5: File Descriptor Leak in DispatchSource
**What goes wrong:** ScreenshotWatcher leaks file descriptors, eventually hitting the process limit.
**Why it happens:** `open()` returns a file descriptor that must be `close()`-ed. If the DispatchSource is cancelled or deallocated without the cancel handler running, the fd leaks.
**How to avoid:** Always set a `setCancelHandler` that closes the file descriptor. Call `source.cancel()` in `deinit` or a `stop()` method. Never let the source be deallocated without cancellation.
**Warning signs:** App crashes with "too many open files" after extended runtime.

## Code Examples

Verified patterns from official sources:

### Reading Clipboard Text and Image
```swift
// Source: Apple NSPasteboard docs
let pasteboard = NSPasteboard.general

// Text
if let string = pasteboard.string(forType: .string) {
    // Use string
}

// Image (check tiff first, then png)
if let data = pasteboard.data(forType: .tiff) {
    let image = NSImage(data: data)
    // Use image
} else if let data = pasteboard.data(forType: .png) {
    let image = NSImage(data: data)
    // Use image
}
```

### Writing Image to Clipboard (avoiding capture loop)
```swift
// Source: Apple NSPasteboard docs + nspasteboard.org conventions
func copyImageToClipboard(_ image: NSImage) {
    isOwnWrite = true  // Flag to skip in observer
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([image])
    // Update lastChangeCount immediately
    lastChangeCount = pasteboard.changeCount
    isOwnWrite = false
}
```

### SMAppService Launch at Login
```swift
// Source: nilcoalescing.com/blog/LaunchAtLoginSetting/
import ServiceManagement

// Register
try? SMAppService.mainApp.register()

// Check status
let isEnabled = SMAppService.mainApp.status == .enabled

// Unregister
try? SMAppService.mainApp.unregister()
```

### Custom Template Image for Menu Bar
```swift
// Source: mirzoyan.dev/blog/custom-icon-menubarextra/
// In MenuBarExtra label:
label: {
    let image: NSImage = {
        let ratio = $0.size.height / $0.size.width
        $0.size.height = 18
        $0.size.width = 18 / ratio
        $0.isTemplate = true  // macOS auto-adapts to light/dark mode
        return $0
    }(NSImage(named: "MenuBarIcon")!)
    Image(nsImage: image)
}
```

### JSON File Persistence for ClipItem Store
```swift
// Source: Standard Foundation Codable pattern
struct ClipItem: Codable, Identifiable {
    let id: UUID
    let type: ItemType
    let content: String?       // Text content (nil for images)
    let thumbnailPath: String? // Relative path to thumbnail
    let filePath: String?      // Relative path to full image
    let timestamp: Date

    enum ItemType: String, Codable {
        case text
        case image
    }
}

class ClipItemStore: ObservableObject {
    @Published var items: [ClipItem] = []
    private let maxItems = 20
    private let storeURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("Copyhog")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        storeURL = appSupport.appendingPathComponent("items.json")
        load()
    }

    func add(_ item: ClipItem) {
        items.insert(item, at: 0)
        if items.count > maxItems {
            let removed = items.removeLast()
            // Clean up associated image file if exists
            if let path = removed.filePath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: storeURL)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data)
        else { return }
        items = decoded
    }
}
```

### Detecting Screenshot Directory
```swift
// Source: macOS defaults system + Apple screencapture domain
func screenshotDirectory() -> URL {
    // Check user's custom screenshot location
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    process.arguments = ["read", "com.apple.screencapture", "location"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
    } catch {}

    // Default: Desktop
    return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `NSStatusItem` + `NSPopover` (AppKit) | `MenuBarExtra` with `.window` style (SwiftUI) | macOS 13 / WWDC 2022 | Pure SwiftUI menu bar apps, no AppDelegate needed |
| `SMLoginItemSetEnabled` (deprecated) | `SMAppService.mainApp.register()` | macOS 13 | Simpler API, no helper app bundle needed |
| `LSSharedFileListInsertItemURL` (deprecated) | `SMAppService` | macOS 13 | Old API removed in recent SDKs |
| FSEvents C API | `DispatchSource.makeFileSystemObjectSource` | Available since macOS 10.12 | Higher-level Swift API, GCD integration, no C callbacks |
| `NSKeyedArchiver` for persistence | `Codable` + `JSONEncoder` | Swift 4 | Type-safe, no `NSCoding` boilerplate |

**Deprecated/outdated:**
- `SMLoginItemSetEnabled`: Replaced by `SMAppService` in macOS 13
- `NSStatusItem` manual popover management: Still works but `MenuBarExtra` is the SwiftUI-native path
- App Sandbox for menu bar utilities using NSEvent monitoring: Not feasible — must disable sandbox for `NSEvent.addGlobalMonitorForEvents`

## Open Questions

1. **Xcode Project vs. SPM-Only**
   - What we know: A proper .app bundle with Info.plist, entitlements, and asset catalog is required. SPM alone cannot produce this.
   - What's unclear: Whether to create the Xcode project via `xcodebuild` automation or require opening Xcode once for initial setup.
   - Recommendation: Create the Xcode project as part of Plan 01-01. Use `xcodebuild` for builds. The initial project scaffold may require Xcode IDE or a template generation script.

2. **Hedgehog Icon Asset**
   - What we know: Menu bar needs a 16px template image (in 22px frame). Must be set as `isTemplate = true` for light/dark mode adaptation.
   - What's unclear: Whether to use an existing hedgehog SF Symbol (none exists) or create a custom silhouette asset.
   - Recommendation: Create a simple hedgehog silhouette PNG (16x16 @1x, 32x32 @2x) for the asset catalog. A placeholder SF Symbol (e.g., `circle.fill`) can be used initially.

3. **Screenshot File Readiness Timing**
   - What we know: DispatchSource fires on directory write, but the file may not be fully written yet.
   - What's unclear: Exact delay needed — varies by screenshot size and system load.
   - Recommendation: Use a 0.5s delay after detection, then verify file size stability (check size, wait 0.2s, check again). If still changing, retry.

## Sources

### Primary (HIGH confidence)
- [Apple NSPasteboard Documentation](https://developer.apple.com/documentation/appkit/nspasteboard) — changeCount polling, data reading, pasteboard types
- [Apple MenuBarExtra Documentation](https://developer.apple.com/documentation/swiftui/menubarextra) — Scene API, window style
- [Apple SMAppService Documentation](https://developer.apple.com/documentation/servicemanagement/smappservice) — Launch at login
- [Apple DispatchSource.makeFileSystemObjectSource Documentation](https://developer.apple.com/documentation/dispatch/dispatchsource/makefilesystemobjectsource(filedescriptor:eventmask:queue:)) — File system monitoring
### Secondary (MEDIUM confidence)
- [Maccy Clipboard.swift](https://github.com/p0deje/Maccy/blob/master/Maccy/Clipboard.swift) — Production clipboard polling pattern, verified against Apple docs
- [nilcoalescing.com — Build a macOS menu bar utility in SwiftUI](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/) — MenuBarExtra setup, LSUIElement, window style sizing
- [mirzoyan.dev — Custom icon for SwiftUI MenuBarExtra](https://mirzoyan.dev/blog/custom-icon-menubarextra/) — NSImage sizing for menu bar icons
- [nilcoalescing.com — Launch at Login Setting](https://nilcoalescing.com/blog/LaunchAtLoginSetting/) — SMAppService toggle pattern
- [swiftrocks.com — DispatchSource file/folder monitoring](https://swiftrocks.com/dispatchsource-detecting-changes-in-files-and-folders-in-swift) — File descriptor setup, event masks, cancel handlers
- [nspasteboard.org](http://nspasteboard.org/) — Transient/auto-generated pasteboard type conventions

### Tertiary (LOW confidence)
- [jano.dev — Accessibility Permission in macOS](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html) — AXIsProcessTrusted vs Input Monitoring distinction (needs validation during implementation)
- [steipete.me — Menu Bar Items 5-Hour Journey](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items) — MenuBarExtra as "second-class citizen" limitations (anecdotal, 2025)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — All system frameworks, no third-party dependencies, verified against Apple docs
- Architecture: HIGH — Pattern well-established by production apps (Maccy, ClipPocket), verified code examples
- Pitfalls: HIGH — Clipboard loop and screenshot timing are documented across multiple sources; accessibility permission requirement verified in Apple docs
- Project setup: MEDIUM — Xcode project creation from CLI is less documented; may need manual Xcode interaction for initial scaffold

**Development environment:**
- Swift 6.2.3, Xcode 26.2, macOS 26.0 (arm64)
- Screenshot default location: ~/Desktop (no custom location set)

**Research date:** 2026-02-20
**Valid until:** 2026-03-20 (stable domain — system frameworks, unlikely to change)
