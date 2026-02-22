# Stack Research

**Domain:** macOS clipboard manager -- power user features (v1.2)
**Researched:** 2026-02-21
**Confidence:** MEDIUM-HIGH

## Context

Copyhog is an existing Swift + SwiftUI macOS menu bar app using MenuBarExtra with `.window` style. Current persistence is JSON file + image files in Application Support. Current history limit is 20 items. This research covers ONLY the stack additions needed for v1.2 power user features: global hotkey, search, keyboard navigation, pinned items, 500+ history, and auto-detect screenshot location.

## Recommended Stack Additions

### Global Hotkey Registration

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 2.x (latest) | User-customizable global keyboard shortcuts | The de facto standard for macOS global hotkeys in Swift. Sandbox-compatible, Mac App Store safe, wraps Carbon APIs cleanly. Used by Dato, Jiffy, Plash, Lungo in production. Includes SwiftUI `Recorder` view for letting users customize their shortcut. Handles edge cases like macOS 15 Option-key restrictions automatically. |

**Integration point:** Define a `KeyboardShortcuts.Name` (e.g., `.toggleCopyhog`) with default `Cmd+Shift+V`. In the `AppDelegate.applicationDidFinishLaunching`, register the shortcut handler to toggle the MenuBarExtra popover.

**Confidence:** HIGH -- verified via Swift Package Index, GitHub releases, multiple production apps.

### Programmatic MenuBarExtra Toggle

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| [MenuBarExtraAccess](https://github.com/orchetect/MenuBarExtraAccess) | 1.2.x | Programmatically show/hide the MenuBarExtra popover | Apple provides NO first-party API to toggle MenuBarExtra presentation state. This library adds a `Bool` binding via `.menuBarExtraAccess(isPresented:)` scene modifier. No private APIs, Mac App Store safe. Required for the global hotkey to actually show the popover. |

**Integration point:** Replace the current `MenuBarExtra` scene with the `.menuBarExtraAccess(isPresented: $isPresented)` modifier. The KeyboardShortcuts handler toggles this binding. Also provides `.introspectMenuBarExtraWindow { window in }` for focus management.

**Confidence:** HIGH -- this is the only viable solution for programmatic MenuBarExtra control. Verified via Swift Package Index, GitHub README, and Apple Feedback reports confirming the gap in first-party APIs.

### Search and Filtering

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| SwiftUI `.searchable()` | Built-in (macOS 13+) | Search bar in the popover | Native SwiftUI modifier, zero dependencies. Works with the existing `@Published var items` array via computed filtered property. |

**No external library needed.** The implementation is straightforward:

```swift
@State private var searchText = ""

var filteredItems: [ClipItem] {
    if searchText.isEmpty { return store.items }
    return store.items.filter { item in
        item.content?.localizedCaseInsensitiveContains(searchText) ?? false
    }
}
```

**Performance note for 500+ items:** SwiftUI List/LazyVGrid diffing can stall when filter results change drastically. Two mitigations:
1. Add `.id(searchText)` on the ScrollView/List to force full recreation instead of diffing
2. Debounce search input by 150-200ms to avoid filtering on every keystroke

**Confidence:** HIGH -- `.searchable()` is stable since macOS 13. Performance patterns verified across multiple Apple Developer Forum threads.

### Keyboard Navigation

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| SwiftUI `@FocusState` + `focusable()` | Built-in (macOS 12+) | Arrow key navigation through clip items | Native focus management. Use `@FocusState` with an enum or optional UUID to track which item has focus. `onMoveCommand` handles arrow key input. |
| `onKeyPress` modifier | Built-in (macOS 14+) | Enter key to paste, Escape to dismiss | Added in macOS 14 Sonoma. Cleaner than `onMoveCommand` for specific key handling. If targeting macOS 13, fall back to `.onExitCommand` for Escape and Button `.keyboardShortcut(.defaultAction)` for Enter. |

**Integration approach:**
```swift
@FocusState private var focusedItem: UUID?

// In the grid/list item:
.focusable()
.focused($focusedItem, equals: item.id)
.onKeyPress(.return) {
    copyItemToPasteboard(item)
    return .handled
}
```

**Critical caveat:** MenuBarExtra popovers have known focus issues. The popover window must become key window for keyboard events to work. MenuBarExtraAccess's `.introspectMenuBarExtraWindow` can help: `window.makeKey()`.

**Confidence:** MEDIUM -- `@FocusState` is well-documented but MenuBarExtra focus behavior requires runtime testing. The `onKeyPress` API is macOS 14+ only.

### Persistence for 500+ Items

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| JSON file persistence (keep current) | N/A | Store clip item metadata | At 500 items, JSON is still fine. A single ClipItem is ~200 bytes of JSON. 500 items = ~100KB file. Load/save is <50ms. The bottleneck is NOT the metadata format -- it's the image files, which are already stored separately. |

**Do NOT migrate to SwiftData or Core Data.** Rationale:
- 500 items of metadata is trivially small for JSON
- SwiftData adds complexity (model container setup, migration versioning) for zero performance gain at this scale
- The current Codable-based persistence is clean, testable, and well-understood
- SwiftData is still maturing (known performance issues vs Core Data as of 2025)
- Migration risk: changing persistence layer while adding features doubles the testing surface

**What DOES need to change:** The `save()` method currently encodes ALL items on every add. At 500 items this is still fast (<50ms), but consider debouncing saves (e.g., coalesce saves within 500ms) to avoid redundant disk writes during rapid clipboard changes.

**Confidence:** HIGH -- JSON performance at this scale is well-understood. SwiftData overhead is not justified.

### Pinned Items

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `isPinned: Bool` field on ClipItem | N/A | Mark items as pinned/favorite | Add a property to the existing Codable model. Pinned items skip the auto-purge logic. No new dependencies needed. |

**Integration point:** Modify `ClipItemStore.add()` to only purge non-pinned items. Sort pinned items to top or into a separate section.

**Confidence:** HIGH -- this is a data model change, no external dependencies.

### Auto-Detect Screenshot Location

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `UserDefaults(suiteName: "com.apple.screencapture")` | Built-in | Read macOS screenshot save directory | The system stores the screenshot location in `defaults read com.apple.screencapture location`. This is readable via `UserDefaults` with the `com.apple.screencapture` suite name. No external library needed. |

**Implementation:**
```swift
func screenshotDirectory() -> URL? {
    if let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }
    // Default: Desktop
    return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
}
```

**Sandbox consideration:** Reading another app's UserDefaults suite requires the `com.apple.security.temporary-exception.shared-preference.read-only` entitlement in a sandboxed app, OR the app must be running outside the sandbox. If sandboxed, an alternative is to shell out: `Process` running `defaults read com.apple.screencapture location`. However, Copyhog appears to not be fully sandboxed (it uses security-scoped bookmarks for file access, suggesting it runs with some sandbox exceptions already).

**Fallback:** If the `com.apple.screencapture` defaults key is not set (user never changed the default), screenshots go to `~/Desktop`. The code must handle this nil case.

**Confidence:** MEDIUM -- the defaults key is well-documented across macOS guides, but sandbox access behavior needs runtime verification in Copyhog's specific entitlements configuration.

## Installation

```bash
# In Xcode: File > Add Package Dependencies

# KeyboardShortcuts
# URL: https://github.com/sindresorhus/KeyboardShortcuts
# Version: 2.0.0 or later

# MenuBarExtraAccess
# URL: https://github.com/orchetect/MenuBarExtraAccess
# Version: 1.2.0 or later
```

No other external dependencies needed. Search, keyboard navigation, pinned items, persistence, and screenshot location detection all use built-in Apple frameworks.

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| KeyboardShortcuts | HotKey (soffes/HotKey) | HotKey is simpler but lacks user-customizable recorder UI, conflict detection, and UserDefaults persistence. KeyboardShortcuts is the complete solution. |
| KeyboardShortcuts | Raw Carbon `RegisterEventHotKey` | Works but requires manual management of registration/unregistration, no SwiftUI integration, no conflict detection. KeyboardShortcuts wraps this cleanly. |
| MenuBarExtraAccess | Custom NSStatusItem | Would require abandoning MenuBarExtra entirely and managing the popover manually via NSPopover or NSPanel. MenuBarExtraAccess preserves the existing SwiftUI MenuBarExtra pattern. |
| JSON persistence | SwiftData | Massive overengineering for 500 items of metadata. Adds migration complexity, model container boilerplate, and SwiftData is still less performant than Core Data. JSON works fine at this scale. |
| JSON persistence | SQLite (GRDB/SQLite.swift) | Only justified at 10K+ items or if full-text search becomes critical. At 500 items, in-memory String.contains() search is instant. |
| `.searchable()` | Custom TextField | `.searchable()` provides standard macOS search bar behavior (placement, keyboard shortcut Cmd+F integration) for free. No reason to build custom. |
| `@FocusState` | Custom NSEvent key handler | `@FocusState` is the SwiftUI-native approach. Custom NSEvent handlers break SwiftUI's focus system and create maintenance burden. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| SwiftData / Core Data | Massive complexity increase for trivial data size. Migration versioning, model containers, fetch descriptors -- all unnecessary for 500 JSON-serializable structs. | Keep current JSON file persistence |
| MASShortcut | Abandoned/unmaintained Objective-C library. Last meaningful update years ago. | KeyboardShortcuts (modern Swift, actively maintained) |
| HotKey (standalone) | Missing recorder UI, conflict detection, UserDefaults persistence. You'd need to build all of that yourself. | KeyboardShortcuts (batteries included) |
| NSPopover (replacing MenuBarExtra) | Would require rewriting the entire menu bar infrastructure. MenuBarExtraAccess solves the programmatic toggle without this rewrite. | MenuBarExtraAccess |
| Combine for search debounce | Overkill. A simple `Task` with `try await Task.sleep` or `.onChange` with `task` modifier achieves the same debounce in fewer lines. | SwiftUI async debounce pattern |

## Version Compatibility

| Package | Requires | Compatible With | Notes |
|---------|----------|-----------------|-------|
| KeyboardShortcuts 2.x | macOS 10.15+, Swift 5.11+ | macOS 13/14/15 | Handles macOS 15 Option-key restriction automatically (fixed in macOS 15.2) |
| MenuBarExtraAccess 1.2.x | macOS 13+ | macOS 13/14/15 | Requires `.menuBarExtraStyle(.window)` which Copyhog already uses |
| `.searchable()` | macOS 13+ | macOS 13/14/15 | Built into SwiftUI |
| `@FocusState` | macOS 12+ | macOS 12/13/14/15 | Built into SwiftUI |
| `onKeyPress` | macOS 14+ | macOS 14/15 | If targeting macOS 13, use `.keyboardShortcut(.defaultAction)` on Button instead |

## Sources

- [KeyboardShortcuts GitHub](https://github.com/sindresorhus/KeyboardShortcuts) -- Package features, compatibility, production usage (HIGH confidence)
- [KeyboardShortcuts Swift Package Index](https://swiftpackageindex.com/sindresorhus/KeyboardShortcuts) -- Version and platform info (HIGH confidence)
- [MenuBarExtraAccess GitHub](https://github.com/orchetect/MenuBarExtraAccess) -- API surface, Mac App Store compatibility (HIGH confidence)
- [Apple Feedback FB10185203](https://github.com/feedback-assistant/reports/issues/328) -- Confirms no first-party API for MenuBarExtra toggle (HIGH confidence)
- [Apple Developer Forums - SwiftUI List performance](https://developer.apple.com/forums/thread/694814) -- `.id()` workaround for filter performance (MEDIUM confidence)
- [WWDC23 - SwiftUI Cookbook for Focus](https://developer.apple.com/videos/play/wwdc2023/10162/) -- `@FocusState`, `focusable()`, `onMoveCommand` patterns (HIGH confidence)
- [Apple NSPasteboard Documentation](https://developer.apple.com/documentation/appkit/nspasteboard) -- Pasteboard API reference (HIGH confidence)
- [Macworld - Screenshot location defaults](https://www.macworld.com/article/673251/how-to-change-where-screenshots-are-saved-on-a-mac.html) -- `com.apple.screencapture location` key (MEDIUM confidence)
- [SwiftData considerations 2025](https://brightdigit.com/articles/swiftdata-considerations/) -- SwiftData maturity assessment (MEDIUM confidence)

---
*Stack research for: Copyhog v1.2 power user features*
*Researched: 2026-02-21*
