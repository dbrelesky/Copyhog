# Pitfalls Research

**Domain:** macOS clipboard manager -- power user features (global hotkey, search, keyboard nav, pinned items, 500+ history)
**Researched:** 2026-02-21
**Confidence:** MEDIUM-HIGH (verified against Maccy source, Apple docs, and community reports; some areas are SwiftUI-version-dependent)

## Critical Pitfalls

### Pitfall 1: MenuBarExtra Has No Programmatic Show/Hide API

**What goes wrong:**
You register a global hotkey (e.g., Cmd+Shift+V) and expect to toggle the popover on keypress. You discover that SwiftUI's `MenuBarExtra` provides zero API to programmatically show or dismiss its window. The hotkey fires, nothing happens. This is a confirmed missing API as of macOS 26 beta 4 (Apple Feedback FB11984872, FB10185203).

**Why it happens:**
Apple built `MenuBarExtra` for click-to-open use cases only. There is no `isPresented` binding, no access to the underlying `NSStatusItem`, and no way to get the popup's `NSWindow`. Developers assume SwiftUI would expose this since it is fundamental behavior for menu bar utilities.

**How to avoid:**
Use the [MenuBarExtraAccess](https://github.com/orchetect/MenuBarExtraAccess) package by orchetect. It provides an `.menuBarExtraAccess(isPresented:)` scene modifier that exposes a binding you can toggle from a global hotkey handler. This is the standard community workaround used by production apps. Important caveat: this only works with `.menuBarExtraStyle(.window)` -- the `.menu` style blocks the runloop and ignores binding changes.

Copyhog already uses `.menuBarExtraStyle(.window)`, so MenuBarExtraAccess will work without style changes.

**Warning signs:**
- Global hotkey fires (confirmed via logging) but popover does not appear
- Attempting to find the MenuBarExtra window in `NSApp.windows` returns inconsistent results
- Trying to use `NSStatusItem.button?.performClick(nil)` as a hack -- this is fragile and breaks across macOS versions

**Phase to address:**
Global hotkey phase (first phase of v1.2). Must be solved before any other keyboard-driven features make sense.

---

### Pitfall 2: JSON File Storage Collapses at 500+ Items with Images

**What goes wrong:**
The current `ClipItemStore` encodes the entire `[ClipItem]` array to JSON and writes it atomically on every add/remove. At 20 items this is instant. At 500+ items with image paths, every clipboard capture triggers a full re-encode and file write. With the 0.5s (or faster 0.1s) poll interval, rapid consecutive copies cause write contention, UI stutters, and potential data corruption from overlapping writes.

**Why it happens:**
JSON persistence is the simplest possible approach and works perfectly at small scale. The problem is not the JSON format itself but the "serialize everything, write everything" pattern. Maccy uses CoreData/SQLite for this exact reason -- even at 50,000 items, their SQLite storage remains performant (the bottleneck moves to UI rendering, not storage).

**How to avoid:**
Migrate from JSON to SQLite (via SwiftData, GRDB, or raw SQLite). SwiftData is the Apple-blessed approach for new Swift apps. The migration path:
1. Keep the JSON loader as a one-time migration reader
2. Create a SwiftData model mirroring `ClipItem`
3. On first launch after update, read `items.json`, insert into SwiftData, delete JSON file
4. All subsequent reads/writes go through SwiftData

SQLite handles concurrent reads during UI rendering while a background write commits new items.

**Warning signs:**
- `save()` calls taking >50ms (profile with Instruments)
- UI hitches when pasting rapidly
- items.json file growing past 1MB
- Race conditions causing items to disappear after rapid copy sequences

**Phase to address:**
Storage migration phase -- must happen BEFORE raising the history limit. Raising the limit on JSON storage is asking for trouble.

---

### Pitfall 3: LazyVGrid with 500+ Image Thumbnails Causes Scroll Lag and Memory Bloat

**What goes wrong:**
The current `PopoverContent` uses `LazyVGrid` inside a `ScrollView` to render item cards. `LazyVGrid` creates views lazily but does NOT recycle them -- once scrolled into view, they stay in memory. With 500+ items, each loading a 64x64 thumbnail via `imageStore.loadImage(relativePath:)` (which creates a new `NSImage` on every call), you get: (a) hundreds of `NSImage` objects in memory, (b) repeated disk I/O as the user scrolls, (c) SwiftUI diffing overhead on the full array when items change.

Maccy's maintainer confirmed this exact issue: even at 50,000 items "the database itself remains performant -- the performance bottleneck occurs during rendering" (GitHub issue #1097).

**Why it happens:**
`ScrollView` + `LazyVStack`/`LazyVGrid` in SwiftUI defers creation but retains offscreen views in memory once created. Apple's `List` view does proper recycling, but `List` does not support the grid layout Copyhog uses. Additionally, `loadImage(relativePath:)` hits the filesystem every time with no caching layer.

**How to avoid:**
1. Add an `NSCache<NSString, NSImage>` layer in `ImageStore` for thumbnails. Thumbnails are 64x64 PNGs (~5-15KB each). 500 cached = ~7MB max, well within reason.
2. Use `List` with a custom row layout that simulates a grid (3 items per row in an `HStack`) instead of `LazyVGrid`. `List` recycles offscreen rows.
3. Alternatively, limit the rendered set: only show the most recent ~100 items in the grid, with a "Load more" button or virtual scrolling. Search results replace the grid entirely.
4. When search is active, filter the data model BEFORE passing to the view. Do not render 500 items and hide 490 with `.opacity(0)`.

**Warning signs:**
- Memory usage climbing as user scrolls through history
- Scroll janking after the list exceeds ~100 items
- Profile showing repeated `NSImage(contentsOf:)` calls in Instruments
- `@Published var items` triggering full view re-evaluation on every add

**Phase to address:**
Must be addressed alongside or before raising history limit to 500+. The thumbnail cache should be added in the storage migration phase. UI virtualization should be addressed in the search/filter phase since search inherently limits visible items.

---

### Pitfall 4: Global Hotkey Conflicts with System and Other Apps

**What goes wrong:**
You hardcode Cmd+Shift+V as the global hotkey. This conflicts with apps that already use it (e.g., Paste app, some IDEs use it for "Paste and Match Style" or "Paste from History"). The hotkey silently fails or, worse, both your app and the other app respond. Users with non-US keyboard layouts may find the shortcut physically awkward or impossible.

**Why it happens:**
macOS global hotkey registration is first-come-first-served. There is no conflict detection API. If another app registered the same shortcut first, your registration may succeed but never fire. The Carbon `RegisterEventHotKey` API (still used under the hood) does not report conflicts.

**How to avoid:**
Use [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) package. It is:
- Fully sandboxed and Mac App Store compatible
- Provides a native SwiftUI `Recorder` view for user-customizable shortcuts
- Handles conflict detection and keyboard layout differences
- Used in production by Dato, Jiffy, Plash, Lungo

Set a sensible default (Cmd+Shift+V) but always let the user change it. Store the binding in UserDefaults. The `KeyboardShortcuts` package handles all of this.

**Warning signs:**
- Hotkey works on your machine but not on testers' machines
- Hotkey stops working after installing another clipboard manager
- Bug reports from users with German/French/Japanese keyboard layouts

**Phase to address:**
Global hotkey phase (first phase of v1.2). Use KeyboardShortcuts from the start rather than rolling a custom implementation.

---

### Pitfall 5: Keyboard Navigation Swallowed by SwiftUI or System

**What goes wrong:**
You add arrow key and Enter handling for navigating clipboard items. The arrow keys get intercepted by the `ScrollView` (which has its own scroll behavior), by macOS accessibility features, or by the `TextField` used for search (which uses arrow keys for cursor movement). Enter key may trigger the search field's default action instead of pasting the selected item. Tab key may cycle focus to unexpected UI elements.

**Why it happens:**
SwiftUI on macOS has a complex responder chain. `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` receives events for your process but competes with SwiftUI's built-in keyboard handling. The `ScrollView` consumes arrow key events for scrolling. `TextField` consumes arrow keys, Enter, and Escape for text editing. There is no clean way to say "I want arrow keys when the list is focused but not when the search field is focused."

**How to avoid:**
1. Use `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` and return `nil` to consume handled events, or return the event to let it propagate.
2. Track focus state explicitly: maintain a `@FocusState` or custom `@State var isSearchFieldFocused: Bool`. When the search field is focused, let arrow keys go to the text field. When the list area is focused, intercept arrow keys for item navigation.
3. Use `.focusable()` and `.focused()` modifiers on the list area to receive keyboard focus properly.
4. Escape key should: (a) if search field is focused with text, clear the search; (b) if search field is focused and empty, move focus to the list; (c) if list is focused, dismiss the popover.
5. Enter key should: paste the currently highlighted item, not submit the search field.

**Warning signs:**
- Arrow keys scroll the view instead of moving selection
- Typing in the search field while arrow keys also move the selection
- Enter key does nothing or triggers unexpected behavior
- Tab key moves focus outside the popover entirely

**Phase to address:**
Keyboard navigation phase -- must come AFTER search is implemented, because the focus management between search field and item list is the hardest part.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keep JSON storage, just raise limit | No migration work | Write contention, corruption risk, slow saves at 500+ | Never -- migrate before raising limit |
| Load full images instead of thumbnails in grid | Simpler code path | 500+ full PNGs in memory = hundreds of MB | Never at 500+ items |
| Hardcode Cmd+Shift+V without recorder | Ship faster | Conflict reports, no fix without app update | MVP only if you ship a Settings shortcut recorder within 2 weeks |
| Skip NSImage cache, reload from disk each render | No cache invalidation logic | Disk I/O on every scroll, visible stutter | Acceptable at 20 items; not at 500+ |
| ~~Store pinned items in a separate JSON file~~ | - | - | Feature removed |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `com.apple.screencapture` defaults | Reading via `UserDefaults(suiteName:)` in a sandboxed app -- returns nil because sandbox blocks cross-domain defaults reads | Use `Process` to run `defaults read com.apple.screencapture location` and parse stdout. In sandbox, this requires a temporary exception or reading the plist file directly from `~/Library/Preferences/com.apple.screencapture.plist` via a security-scoped bookmark. Alternatively, use `NSAppleScript` to run the defaults command. |
| MenuBarExtraAccess + KeyboardShortcuts | Registering the hotkey handler before MenuBarExtraAccess has initialized its binding -- the binding toggle fires but the window is not yet wired | Initialize MenuBarExtraAccess in the `App` scene body, then register the KeyboardShortcuts handler in `AppDelegate.applicationDidFinishLaunching`. The scene body executes before the delegate callback, ensuring the binding is ready. |
| SwiftData migration from JSON | Running migration on the main thread -- blocks app launch for seconds with 500+ items | Run migration on a background task, show a one-time "Upgrading..." indicator. Mark the migration as complete with a UserDefaults flag so it only runs once. |
| NSPasteboard write after hotkey paste | Writing to pasteboard from the hotkey handler while the popover is still visible -- the ClipboardObserver detects its own write as a new clipboard change, creating a duplicate | Set a "self-write" flag on `ClipboardObserver` before writing, and skip the next `changeCount` change if the flag is set. Copyhog may already handle this (check `ClipboardObserver` implementation). |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Full-array JSON encode on every clipboard change | UI hitch on paste, items.json write time >100ms | Migrate to SQLite/SwiftData with incremental writes | ~100+ items with images |
| NSImage loaded from disk per grid cell render | Scroll stutter, high disk I/O in Instruments | NSCache thumbnail layer, load thumbnails async | ~50+ visible image cells |
| `@Published var items` diffing entire array | SwiftUI re-evaluates all ItemRow views when any item changes | Use `List` with `Identifiable` items (SwiftUI can diff by ID). Or use `@Observable` (macOS 14+) instead of `ObservableObject` for finer-grained updates | ~100+ items in the published array |
| Search filtering on every keystroke against 500+ items with string matching | Typing lag in search field | Debounce search input (300ms), search on the content column with SQLite FTS if using database, or simple `localizedCaseInsensitiveContains` with debounce | ~200+ text items |
| Thumbnail generation blocking clipboard capture | Screenshot capture appears delayed | Generate thumbnails on a background queue, insert item with a placeholder, update thumbnail path when generation completes | When user takes rapid screenshots |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| ~~Pinned items containing passwords~~ | - | Feature removed |
| Search indexing sensitive/redacted items | Searching for "password" reveals which items were from password managers (even if content is redacted, the existence is metadata) | Exclude items where `isSensitive == true` from search results entirely. |
| Global hotkey handler logging clipboard content for debugging | Debug logs contain passwords in plaintext | Never log clipboard content. Log item types and counts only. Strip debug logging before release builds. |
| Storing full screenshots at original resolution indefinitely | 500+ screenshots at 5-10MB each = 2.5-5GB disk usage | Compress stored images (JPEG at 80% quality for screenshots), implement a separate disk usage cap, or store only thumbnails after N days. |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Global hotkey opens popover but does not focus the search field | User presses hotkey, then has to click the search field -- defeats keyboard-driven workflow | Auto-focus search field when popover opens via hotkey (but NOT when opened via menu bar click, since click users may want to browse) |
| Arrow key navigation has no visible selection indicator | User presses arrow keys but cannot tell which item is "selected" | Add a visible highlight ring/background on the keyboard-selected item, distinct from the hover highlight |
| ~~Pinned items mixed into list~~ | - | Feature removed |
| Search clears when popover closes | User searches, copies an item, popover closes, reopens -- search is gone and they are back at the full list | Persist search text for the session (clear on app restart, not on popover dismiss). Or provide a "recent searches" shortcut. |
| No empty state for search results | User searches for something that does not exist, sees a blank white space | Show "No results for [query]" with a suggestion to clear the search |
| Hotkey pastes item but does not dismiss popover or switch to previous app | User has to manually close popover and click back to their app | After paste via Enter key: dismiss popover, then use `NSWorkspace` to activate the previous app, then optionally simulate Cmd+V to paste from the now-populated system clipboard |

## "Looks Done But Isn't" Checklist

- [ ] **Global hotkey:** Works when app is not frontmost -- verify it fires when another app has focus (test with a full-screen app)
- [ ] **Global hotkey:** Works after sleep/wake cycle -- some event tap registrations break after sleep
- [ ] **Keyboard navigation:** Arrow keys work in both the grid layout and any future list layout -- grid requires 2D navigation (left/right/up/down), not just up/down
- [ ] **Search:** Handles unicode, emoji, and CJK characters correctly in filter matching
- [ ] **Search:** Does not crash or hang on extremely long text items (e.g., user copied a 50KB log file)
- [x] ~~**Pinned items:**~~ Feature removed
- [ ] **500+ history:** Startup time remains under 2 seconds -- loading 500+ items from storage on launch must not block the main thread
- [ ] **Screenshot location detection:** Falls back gracefully when user has not customized location (default is Desktop, but `defaults read com.apple.screencapture location` returns error when unset)
- [ ] **Screenshot location detection:** Handles paths with spaces and special characters (e.g., `~/Documents/My Screenshots`)

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| JSON corruption at scale | MEDIUM | Keep a backup of the last valid JSON before migration. If SwiftData migration fails, fall back to empty state with a user notification. Never silently lose data. |
| Hotkey conflict with another app | LOW | KeyboardShortcuts package lets user re-bind. Add a "Reset to default" button. |
| Memory bloat from thumbnail loading | LOW | Add NSCache with `countLimit`. Existing images on disk are fine; just need the caching layer. |
| Search performance on large history | LOW | Add debounce. If still slow, add SQLite FTS index -- this is additive, not a rewrite. |
| Keyboard nav focus bugs | MEDIUM | Requires careful focus state management. If SwiftUI focus APIs are insufficient, fall back to `NSEvent.addLocalMonitorForEvents` with explicit state tracking. |
| MenuBarExtraAccess breaking on new macOS version | MEDIUM | The package uses private API introspection. Pin to a specific version. Monitor the package repo for macOS compatibility updates before upgrading. Have a fallback: if MenuBarExtraAccess fails, degrade to "hotkey copies last item to clipboard" without showing the popover. |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| MenuBarExtra no programmatic show/hide | Global Hotkey phase | Hotkey toggles popover open/closed from any app |
| JSON storage collapse at scale | Storage Migration phase (before history limit raise) | Profile save() at 500 items -- must be <10ms |
| LazyVGrid memory/scroll issues | UI Performance phase (with history limit raise) | Scroll through 500 items without visible stutter; memory stays under 150MB |
| Global hotkey conflicts | Global Hotkey phase | Works on 3+ test machines with different apps installed |
| Keyboard nav focus conflicts | Keyboard Navigation phase (after search) | Arrow keys navigate items when list focused; type in search field without triggering navigation |
| Screenshot location sandbox access | Screenshot Detection phase | Auto-detects custom screenshot location on a fresh macOS install with and without customization |
| ~~Pinned items surviving purge~~ | - | Feature removed |
| Search performance on large history | Search phase | Type a query against 500 items, results appear within 300ms |

## Sources

- [MenuBarExtraAccess](https://github.com/orchetect/MenuBarExtraAccess) -- programmatic popover show/hide for MenuBarExtra
- [Apple FB11984872](https://github.com/feedback-assistant/reports/issues/383) -- confirms no first-party programmatic show/hide API
- [Apple FB10185203](https://github.com/feedback-assistant/reports/issues/328) -- original feature request for MenuBarExtra isPresented
- [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) -- App Store compatible global hotkeys with SwiftUI recorder
- [Maccy Issue #1097](https://github.com/p0deje/Maccy/issues/1097) -- performance bottleneck is rendering, not storage, at 50K items
- [Maccy Issue #310](https://github.com/p0deje/Maccy/issues/310) -- unlimited clipboard data discussion, SQLite storage approach
- [SwiftUI List vs LazyVStack performance](https://fatbobman.com/en/posts/list-or-lazyvstack/) -- detailed benchmarks showing List recycles views, LazyVStack does not
- [Apple Forums: SwiftUI List performance slow on macOS](https://developer.apple.com/forums/thread/650238) -- confirms macOS-specific SwiftUI rendering issues
- [CGImageSource thumbnail performance](https://macguru.dev/fast-thumbnails-with-cgimagesource/) -- CGImageSource is 10-40x faster than NSImage for thumbnails
- [macOS defaults: screenshot location](https://macos-defaults.com/screenshots/location.html) -- `defaults read com.apple.screencapture location`
- [Peter Steinberger: Menu bar settings](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items) -- confirms menu bar apps are "second-class citizens" in SwiftUI as of 2025
- [Apple Developer Forums: Global hotkeys](https://developer.apple.com/forums/thread/735223) -- RegisterEventHotKey deprecated, use modern alternatives

---
*Pitfalls research for: Copyhog v1.2 Power User Features*
*Researched: 2026-02-21*
