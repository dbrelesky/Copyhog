# Architecture Research

**Domain:** macOS clipboard manager -- power user features (v1.2)
**Researched:** 2026-02-21
**Confidence:** MEDIUM-HIGH

## Existing Architecture Snapshot

Before describing integration, here is how Copyhog is structured today:

```
CopyhogApp (@main)
  └── MenuBarExtra(.window style)
        └── PopoverContent (SwiftUI)
              ├── PreviewPane (top half)
              ├── Toolbar (multi-select, settings)
              └── ScrollView > LazyVGrid > ItemRow (3-column grid)

AppDelegate (@MainActor)
  ├── ClipItemStore       ── @Published items: [ClipItem], JSON file persistence
  │     └── ImageStore    ── saves PNGs + 64x64 thumbs in App Support/Copyhog/
  ├── ClipboardObserver   ── polls NSPasteboard.general.changeCount every 100ms
  │     └── ExclusionManager / PasswordDetector
  ├── ScreenshotWatcher   ── DispatchSource FSEvents on user-chosen directory
  ├── BookmarkManager     ── security-scoped bookmarks for folder access
  └── PasteboardWriter    ── static methods to write items back to NSPasteboard
```

**Key constraints of existing design:**
- All services are `@MainActor`. Fine for current scale, but important for new feature integration.
- `MenuBarExtra(.window)` has NO first-party API for programmatic show/hide. This is the central architectural challenge for global hotkey.
- Persistence is a single `items.json` file encoded/decoded in full on every mutation. Currently ~20 items. Will not scale to 500+.
- `ClipItem` is a flat struct. Purge logic removes the oldest items when the limit is exceeded.

## System Overview After v1.2

```
┌─────────────────────────────────────────────────────────────────┐
│                       App Entry (CopyhogApp)                     │
│  MenuBarExtra(.window) + MenuBarExtraAccess (isPresented binding)│
├─────────────────────────────────────────────────────────────────┤
│                       AppDelegate (@MainActor)                   │
│  ┌──────────────┐  ┌───────────────────┐  ┌──────────────────┐  │
│  │  HotKey       │  │  ClipboardObserver │  │ ScreenshotWatcher│  │
│  │  (global      │  │  (polls pasteboard │  │ (FSEvents on     │  │
│  │   shortcut)   │  │   every 100ms)     │  │  auto-detected   │  │
│  │              │  │                    │  │  + manual dir)   │  │
│  └──────┬───────┘  └────────┬──────────┘  └───────┬──────────┘  │
│         │ toggle             │ onNewItem           │ onNewItem   │
│         │ isPresented        │                     │             │
├─────────┴────────────────────┴─────────────────────┴────────────┤
│                       ClipItemStore (@MainActor)                 │
│  ┌────────────┐  ┌──────────────┐  ┌─────────────────────────┐  │
│  │ items:      │  │ pinnedItems:  │  │ filteredItems(query:)   │  │
│  │ [ClipItem]  │  │ [ClipItem]   │  │ computed property       │  │
│  └─────┬──────┘  └──────┬───────┘  └─────────────────────────┘  │
│        │                │                                        │
│  ┌─────┴────────────────┴───────────────────────────────────┐   │
│  │              Persistence Layer (JSON or SQLite)            │   │
│  │   items.json  OR  GRDB SQLite (if 500+ proves slow)       │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    ImageStore                              │   │
│  │   App Support/Copyhog/ -- full PNGs + 64x64 thumbnails    │   │
│  └──────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│                       PopoverContent (SwiftUI)                   │
│  ┌─────────────┐  ┌─────────────────────────────────────────┐   │
│  │ SearchBar    │  │ KeyboardNavigationHandler               │   │
│  │ (TextField)  │  │ (NSEvent.addLocalMonitorForEvents)      │   │
│  └──────┬──────┘  └──────┬──────────────────────────────────┘   │
│         │ searchQuery     │ selectedIndex / Enter action         │
│  ┌──────┴────────────────┴──────────────────────────────────┐   │
│  │  PreviewPane ── Toolbar ── ScrollView > LazyVGrid         │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities (New + Modified)

| Component | Status | Responsibility | Integrates With |
|-----------|--------|----------------|-----------------|
| **HotKey** (soffes/HotKey SPM) | NEW | Register global Cmd+Shift+V, fire toggle callback | AppDelegate, MenuBarExtraAccess binding |
| **MenuBarExtraAccess** (orchetect SPM) | NEW | Expose `isPresented` binding for MenuBarExtra popover | CopyhogApp scene, HotKey callback |
| **SearchBar** | NEW view | Text field at top of PopoverContent, binds to `searchQuery` | PopoverContent, ClipItemStore filtering |
| **KeyboardNavigationHandler** | NEW | NSEvent local monitor for arrow keys + Enter inside popover | PopoverContent, ClipItemStore, PasteboardWriter |
| **ScreenshotLocationDetector** | NEW | Read `com.apple.screencapture` defaults for auto-detect | ScreenshotWatcher, BookmarkManager |
| **ClipItemStore** | MODIFIED | Search filtering, higher limit, possible SQLite migration | All views, persistence layer |
| **PopoverContent** | MODIFIED | Add search bar, keyboard nav state | SearchBar, KeyboardNavigationHandler |
| **ItemRow** | MODIFIED | Context menu actions | ClipItemStore |
| **ScreenshotWatcher** | MODIFIED | Accept auto-detected path as fallback when no bookmark exists | ScreenshotLocationDetector |

## Feature-by-Feature Integration Analysis

### 1. Global Hotkey (Cmd+Shift+V)

**The problem:** `MenuBarExtra(.window)` has no first-party API to programmatically show or hide the popover. Apple has acknowledged this gap (FB10185203, FB11984872) but has not shipped a fix.

**Solution:** Use two SPM packages together:

1. **[soffes/HotKey](https://github.com/soffes/HotKey)** (v0.2.1+) -- wraps Carbon `RegisterEventHotKey` APIs. Lifecycle-managed: register on init, unregister on deinit. Simple closure-based API. Use this over sindresorhus/KeyboardShortcuts because we want a hard-coded shortcut (Cmd+Shift+V), not a user-customizable one with a UI recorder.

2. **[orchetect/MenuBarExtraAccess](https://github.com/orchetect/MenuBarExtraAccess)** -- adds `.menuBarExtraAccess(isPresented:)` modifier to `MenuBarExtra` scene. Provides a `@State var isPresented: Bool` binding that can toggle the popover programmatically.

**Integration point in CopyhogApp.swift:**

```swift
import MenuBarExtraAccess
import HotKey

@main
struct CopyhogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var isMenuPresented = false

    var body: some Scene {
        MenuBarExtra {
            PopoverContent()
                .environmentObject(appDelegate.store)
                .environmentObject(appDelegate.exclusionManager)
                .frame(width: 400, height: 520)
        } label: {
            // ... existing icon code
        }
        .menuBarExtraStyle(.window)
        .menuBarExtraAccess(isPresented: $isMenuPresented)  // NEW
    }
}
```

**Integration point in AppDelegate:**

```swift
private var hotKey: HotKey?

func setupGlobalHotkey(toggleBinding: Binding<Bool>) {
    hotKey = HotKey(key: .v, modifiers: [.command, .shift])
    hotKey?.keyDownHandler = {
        toggleBinding.wrappedValue.toggle()
    }
}
```

**Challenge:** Passing the `@State` binding from `CopyhogApp` (a struct) to `AppDelegate` (a class). Options:
- (A) Use `@Published var isPresented` on AppDelegate and bind with `$appDelegate.isPresented` -- **recommended**, cleanest data flow.
- (B) Use NotificationCenter to post a toggle event -- works but indirect.
- (C) Hold the HotKey in the App struct itself using `onAppear` -- fragile lifecycle.

**Confidence:** MEDIUM. MenuBarExtraAccess is a third-party workaround for a missing Apple API. It works by runtime introspection of NSStatusItem internals. Risk of breakage on major macOS updates. No alternative exists. The library is well-maintained and widely used in the community.

### 2. Search / Filter

**Where filtering logic lives:** `ClipItemStore` -- add a computed property or method that filters `items` based on a query string.

```swift
// In ClipItemStore
@Published var searchQuery: String = ""

var displayItems: [ClipItem] {
    let base = items  // includes pinned at top (see pinned items section)
    guard !searchQuery.isEmpty else { return base }
    return base.filter { item in
        switch item.type {
        case .text:
            return item.content?.localizedCaseInsensitiveContains(searchQuery) ?? false
        case .image:
            return false  // images don't have searchable text content
        }
    }
}
```

**UI integration:** Add a `TextField` at the top of `PopoverContent`, between the preview pane and the toolbar (or above the preview pane). Bind to `store.searchQuery`.

**Why not search images:** OCR is out of scope per PROJECT.md constraints. Image items simply don't match text searches. This is standard behavior in clipboard managers (Maccy, Paste, etc.).

**Performance at 500 items:** `localizedCaseInsensitiveContains` on 500 strings is sub-millisecond. No indexing needed.

**Confidence:** HIGH. Standard SwiftUI pattern, no external dependencies.

### 3. Keyboard Navigation

**The challenge:** SwiftUI's built-in focus/keyboard navigation (`.focusable()`, `@FocusState`) works poorly inside `MenuBarExtra(.window)` popovers. The popover's `NSPanel` has non-standard first-responder behavior.

**Solution:** Use `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` inside PopoverContent to intercept arrow keys and Enter. Track a `@State var selectedIndex: Int?` that highlights the active item in the grid.

```swift
// In PopoverContent
@State private var selectedIndex: Int? = nil

.onAppear {
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        switch event.keyCode {
        case 125: // Down arrow
            moveSelection(by: 1)
            return nil  // consume event
        case 126: // Up arrow
            moveSelection(by: -1)
            return nil
        case 36:  // Enter/Return
            pasteSelectedItem()
            return nil
        default:
            return event  // pass through
        }
    }
}
```

**Grid navigation:** The current layout is a 3-column `LazyVGrid`. Arrow down/up should move by +3/-3 indices (next/previous row). Left/right arrows move by +1/-1. This maps naturally to a flat index over `displayItems`.

**Visual highlight:** Add a highlight border/background to the `ItemRow` at `selectedIndex`. The `hoveredItemID` pattern already exists -- extend it with a `selectedIndex`-based equivalent.

**Enter-to-paste flow:** When Enter is pressed with a `selectedIndex`, call `PasteboardWriter.write()` for that item, then dismiss the popover (set `isPresented = false`).

**Auto-focus search on open:** When the popover appears, the search TextField should auto-gain focus. Typing should filter immediately. Arrow keys should shift from search to grid navigation.

**Confidence:** MEDIUM. NSEvent local monitors work in NSPanel popovers, but the interaction between SwiftUI focus system and raw event monitoring needs careful testing. The `onDisappear` cleanup of the monitor is critical to avoid leaks.

### 4. 500+ Item History (Pinned Items Feature Removed)

**Current bottleneck:** `ClipItemStore` encodes the ENTIRE `[ClipItem]` array to JSON and writes to disk on every single `add()` call. At 500 items with text content, the JSON file could be 500KB-2MB. Re-encoding and writing atomically on every clipboard change (potentially multiple times per second) will cause noticeable lag.

**Recommendation: Start with optimized JSON, migrate to SQLite only if needed.**

**Phase 1 -- Optimized JSON (try first):**
- Debounce saves: instead of saving on every `add()`, debounce with a 1-second timer. Save immediately on `applicationWillTerminate`.
- Lazy load: load items on startup, keep in memory. The in-memory array is fine for 500 items.
- This is likely sufficient. 500 `ClipItem` structs (text content capped, image data is just file paths) will be < 1MB JSON. Encoding 1MB of Codable structs takes < 10ms on any modern Mac.

**Phase 2 -- SQLite via GRDB (if JSON proves slow):**
- [GRDB.swift](https://github.com/groue/GRDB.swift) is the standard choice for SQLite in Swift. It outperforms both CoreData and SwiftData for raw read/write operations.
- Do NOT use SwiftData: it is slower than CoreData and adds unnecessary abstraction for a simple key-value + metadata store.
- Do NOT use CoreData: overkill for this use case, and its `@MainActor` integration with SwiftUI is awkward.
- GRDB provides `Record` types that work like Codable structs, so migration from JSON would be mechanical.

**Thumbnail storage at 500+ items:** Each item stores two files (full PNG + 64x64 thumb). At 500 items, that is ~1000 files in a flat directory. This is fine for macOS APFS -- directory listing performance is O(1) per lookup. No need to shard into subdirectories until 10,000+ files.

**Memory consideration:** Thumbnails are loaded on-demand by `ImageStore.loadImage()`. The `LazyVGrid` only renders visible cells, so memory usage stays bounded regardless of item count.

**Confidence:** HIGH for optimized JSON approach. MEDIUM for GRDB migration path (well-documented but untested in this codebase).

### 6. Auto-Detect Screenshot Location

**How macOS stores the screenshot location:**

```swift
// Read the screenshot save location from macOS system preferences
let screenshotDefaults = UserDefaults(suiteName: "com.apple.screencapture")
let location = screenshotDefaults?.string(forKey: "location")
// Returns: "/Users/username/Desktop" (default) or custom path
// Returns nil if never explicitly set (defaults to Desktop)
```

**Integration with existing ScreenshotWatcher:**

Create a new `ScreenshotLocationDetector` utility:

```swift
struct ScreenshotLocationDetector {
    /// Returns the macOS screenshot save directory.
    /// Reads from com.apple.screencapture defaults, falls back to ~/Desktop.
    static func detect() -> URL {
        if let defaults = UserDefaults(suiteName: "com.apple.screencapture"),
           let location = defaults.string(forKey: "location") {
            return URL(fileURLWithPath: (location as NSString).expandingTildeInPath)
        }
        // Default: ~/Desktop
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
    }
}
```

**Impact on onboarding flow:**

Currently, the user must manually select the screenshot source directory during onboarding (BookmarkManager stores a security-scoped bookmark). With auto-detection:

1. On first launch, auto-detect the screenshot directory.
2. If it is ~/Desktop (the default), skip the source folder picker entirely.
3. Still require the user to confirm or choose the Screenies destination folder.
4. Fall back to manual selection if auto-detect fails or user wants to override.

**Sandbox consideration:** Reading `UserDefaults(suiteName: "com.apple.screencapture")` works without sandbox entitlements because it reads from the user's preferences domain. However, ACCESSING the detected directory still requires either: (a) a security-scoped bookmark (current approach), or (b) the app being non-sandboxed. Since Copyhog already uses security-scoped bookmarks, auto-detection just pre-fills the path -- the user still needs to grant access via NSOpenPanel the first time.

**Optimization:** Auto-detect the path and pre-navigate the NSOpenPanel to that directory. The user confirms with one click instead of manually navigating.

**Confidence:** HIGH. `UserDefaults(suiteName:)` for reading system preferences is a well-established pattern. The `com.apple.screencapture` domain with `location` key is stable and documented.

## Data Flow Changes

### Current Data Flow (v1.0)

```
NSPasteboard change → ClipboardObserver.pollClipboard()
    → ClipItem created
    → ClipItemStore.add()
    → items.insert(at: 0), purge excess, save JSON
    → @Published triggers SwiftUI re-render
    → PopoverContent > LazyVGrid rebuilds
```

### New Data Flow (v1.2)

```
NSPasteboard change → ClipboardObserver.pollClipboard()
    → ClipItem created
    → ClipItemStore.add()
    → items.insert(at: 0)
    → purge oldest items beyond cap
    → debounced save (JSON or SQLite)
    → @Published triggers SwiftUI re-render
    → displayItems applies: search filter
    → PopoverContent > SearchBar + LazyVGrid rebuilds
    → KeyboardNavigationHandler updates selectedIndex

Global Hotkey (Cmd+Shift+V) → HotKey callback
    → toggle isPresented binding (MenuBarExtraAccess)
    → popover appears/disappears
    → onAppear: focus search bar, install key monitor
    → onDisappear: remove key monitor, clear search

User types in search → searchQuery updates
    → displayItems recomputed (filtered)
    → LazyVGrid re-renders with filtered items
    → selectedIndex resets to 0

Arrow key / Enter → NSEvent local monitor
    → selectedIndex updated → highlight moves
    → Enter: PasteboardWriter.write(selectedItem)
    → isPresented = false (dismiss popover)
```

## Architectural Patterns

### Pattern 1: Binding Bridge Between App Struct and AppDelegate

**What:** The `@State` or `@Published` property for `isPresented` must be accessible from both the SwiftUI scene (CopyhogApp) and the imperative HotKey callback (AppDelegate). Use `@Published` on AppDelegate since it is already `ObservableObject`.

**When to use:** Any time you need to bridge SwiftUI declarative state with imperative AppKit/Carbon callbacks.

**Trade-offs:** Adds a dependency from `CopyhogApp` scene to `AppDelegate` state. Acceptable since AppDelegate already owns all services.

### Pattern 2: Computed Display List

**What:** Instead of storing separate filtered/sorted arrays, compute `displayItems` from the source `items` array on access. Search filtering happens in one computed property.

**When to use:** When the source data is small enough that recomputation is cheaper than cache invalidation (500 items qualifies).

**Trade-offs:** Recomputes on every access. Fine for 500 items. Would need caching at 10,000+.

### Pattern 3: Local Event Monitor with Lifecycle Cleanup

**What:** Install `NSEvent.addLocalMonitorForEvents` in `onAppear`, remove in `onDisappear`. Store the monitor reference for cleanup.

**When to use:** Keyboard handling inside MenuBarExtra popovers where SwiftUI focus system is unreliable.

**Trade-offs:** Bypasses SwiftUI's declarative event handling. Must manually manage monitor lifecycle to avoid leaks or double-installs.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Using SwiftUI @FocusState in MenuBarExtra

**What people do:** Try to use `@FocusState` and `.focused()` modifiers for keyboard navigation inside MenuBarExtra popovers.

**Why it's wrong:** MenuBarExtra's NSPanel has non-standard first-responder chain. `@FocusState` often fails to activate, especially after the popover is dismissed and re-shown.

**Do this instead:** Use `NSEvent.addLocalMonitorForEvents` for reliable keyboard event capture. It works regardless of focus state.

### Anti-Pattern 2: Full Array Re-encode on Every Clipboard Change

**What people do:** Encode and write the entire items array to JSON synchronously on every `add()` call.

**Why it's wrong:** At 500 items, this means encoding potentially 1MB+ of JSON multiple times per second during rapid clipboard use (e.g., user copying multiple items quickly).

**Do this instead:** Debounce saves with a 1-second timer. Trigger immediate save on `applicationWillTerminate`.

## Suggested Build Order

Features have dependencies. Build in this order:

```
Phase 1: Auto-detect screenshot location
  └── No dependencies on other features
  └── Simplifies onboarding (user benefit immediately)
  └── Low risk, isolated change

Phase 2: 500+ history limit
  └── Debounced save
  └── NSCache thumbnail caching

Phase 3: Search
  └── SearchBar UI + filtering logic
  └── Foundation for keyboard navigation

Phase 4: Global hotkey + keyboard navigation
  └── Depends on: Search (keyboard nav starts in search field)
  └── MenuBarExtraAccess + HotKey SPM packages
  └── NSEvent local monitor for arrow keys + Enter
  └── Highest integration complexity -- touches App struct, AppDelegate, PopoverContent
```

**Rationale:**
- Auto-detect is fully isolated, ships value with zero risk to other features.
- 500+ history limit modifies purge logic and persistence.
- Search is a prerequisite for keyboard navigation (users summon with hotkey, type to search, arrow to select, Enter to paste -- this is the core power-user flow).
- Global hotkey + keyboard nav is the capstone. It ties everything together and has the most integration points. Build it last when the underlying pieces are stable.

## Integration Points Summary

| New Feature | Files Modified | Files Created | SPM Packages |
|------------|---------------|--------------|-------------|
| Auto-detect screenshot | ScreenshotWatcher, OnboardingView, BookmarkManager | ScreenshotLocationDetector.swift | none |
| ~~Pinned items~~ | ~~Removed~~ | - | - |
| 500+ history | ClipItemStore (debounced save) | none (GRDB only if needed) | none (GRDB only if needed) |
| Search | PopoverContent, ClipItemStore | SearchBar.swift (or inline) | none |
| Global hotkey | CopyhogApp, AppDelegate | none | HotKey, MenuBarExtraAccess |
| Keyboard nav | PopoverContent, ItemRow | KeyboardNavigationHandler (or inline) | none |

## Sources

- [orchetect/MenuBarExtraAccess](https://github.com/orchetect/MenuBarExtraAccess) -- programmatic show/hide for MenuBarExtra (MEDIUM confidence, third-party workaround)
- [soffes/HotKey](https://github.com/soffes/HotKey) -- global keyboard shortcuts via Carbon APIs (HIGH confidence, stable library)
- [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) -- alternative for user-customizable shortcuts (not recommended for this use case)
- [groue/GRDB.swift](https://github.com/groue/GRDB.swift) -- SQLite toolkit, fallback if JSON proves slow at 500+ items (HIGH confidence)
- [Apple FB10185203](https://github.com/feedback-assistant/reports/issues/328) -- acknowledged gap in MenuBarExtra API
- [Apple FB11984872](https://github.com/feedback-assistant/reports/issues/383) -- programmatic close request for MenuBarExtra
- [GRDB Performance Wiki](https://github.com/groue/GRDB.swift/wiki/Performance) -- benchmarks showing GRDB > CoreData > SwiftData
- macOS `com.apple.screencapture` defaults domain -- standard system preference for screenshot location

---
*Architecture research for: Copyhog v1.2 Power User Features*
*Researched: 2026-02-21*
