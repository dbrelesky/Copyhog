# Phase 8: Search + Keyboard Navigation - Research

**Researched:** 2026-02-22
**Domain:** SwiftUI search filtering, NSEvent keyboard handling in MenuBarExtra popovers
**Confidence:** HIGH

## Summary

Phase 8 adds two tightly coupled features to Copyhog: (1) a search field that filters clipboard history items in real-time as the user types, and (2) full keyboard navigation so users can arrow through items and press Enter to copy without touching the mouse. The current codebase has a sectioned layout (Pinned + History) using `LazyVStack` with `LazyVGrid` sections, a `ClipItemStore` with `@Published items`, and an existing hover-based `hoveredItemID` pattern in PopoverContent.

The core technical challenges are: adding a search TextField that coexists with the existing sectioned layout, implementing `NSEvent.addLocalMonitorForEvents` for reliable keyboard handling inside the MenuBarExtra popover (since SwiftUI's `@FocusState` is unreliable in NSPanel windows), managing focus transitions between the search field and the item list, making the Escape key context-sensitive (clear search first, then dismiss), and ensuring the 3-column grid navigation maps arrow keys to logical item movements.

**Primary recommendation:** Add `searchQuery` as `@Published` on ClipItemStore with a `displayItems` computed property that handles both pin sorting and search filtering. Use `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` for keyboard navigation with a tracked `selectedIndex`. Use a standard SwiftUI `TextField` for search (not `.searchable()` which has placement issues in MenuBarExtra). Debounce search input at 150ms for smooth real-time filtering.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Search field requires explicit focus -- no typeahead from anywhere in the popover
- On popover open, focus lands on the first list item (not the search field) -- optimized for quick arrow-key + Enter workflows
- Placeholder text: "Search history..."
- Tab moves focus between search field and list; Shift+Tab goes back
- Search filters pinned and regular items equally -- pinned items are hidden if they don't match the query
- Matched text should be visually highlighted (bold or color) in the filtered results
- Clearing the search field restores the full list with pinned items back at the top
- Arrow keys stop at edges -- no wrap-around (down at last item does nothing, up at first does nothing)
- Tab navigates between search field and list; Shift+Tab reverses direction
- Enter on a selected item copies it to clipboard
- Escape clears search text first if present, then dismisses popover on second press

### Claude's Discretion
- Search field visual treatment (search icon, clear button, styling)
- What gets searched -- text content only vs also including source app name
- No-results empty state messaging and design
- Behavior when typing while list is focused (redirect to search vs ignore)
- Preview pane update timing when arrowing through items (immediate vs debounced)
- Search debounce timing for real-time filtering

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SRCH-01 | User can type in a search field at the top of the popover to filter clipboard history by text content | TextField bound to `searchQuery` on ClipItemStore; `displayItems` computed property filters by `localizedCaseInsensitiveContains` |
| SRCH-02 | Search results update in real-time as the user types (debounced) | 150ms debounce via Task.sleep on `.onChange(of: searchText)`; `localizedCaseInsensitiveContains` on 500 strings is sub-millisecond |
| SRCH-03 | When search field is cleared, the full history list is restored | `displayItems` returns full pinned+unpinned list when `searchQuery.isEmpty`; existing sectioned layout restores automatically |
| KBNAV-01 | User can press arrow keys to move selection through items in the popover | `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` tracks `selectedIndex`; arrow down/up move by +1/-1 in flattened display list; left/right move within 3-column grid row |
| KBNAV-02 | User can press Enter on a selected item to copy it (or paste-on-select if enabled) | Enter keyCode (36) in the event monitor calls `PasteboardWriter.write()` for `displayItems[selectedIndex]` |
| KBNAV-03 | User can press Escape to dismiss the popover | Escape keyCode (53) in event monitor: if search has text, clear it; if search is empty, close the popover panel via `NSApp.windows` lookup |
| KBNAV-04 | When popover opens via hotkey, the search field is focused and ready for typing | **NOTE:** This requirement references hotkey behavior which is Phase 9 scope. For Phase 8, the user decided focus lands on the first list item on open. Phase 9 will override this for hotkey-triggered opens. Phase 8 should build the infrastructure (`isSearchFocused` state) so Phase 9 can set it. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI TextField | macOS 14+ | Search input field | Already in use; standard text input with binding |
| NSEvent.addLocalMonitorForEvents | AppKit (macOS 10.6+) | Intercept keyboard events in popover | Reliable in NSPanel windows where SwiftUI @FocusState fails; recommended in v1.2 architecture research |
| Foundation String | macOS 14+ | Case-insensitive text matching | `localizedCaseInsensitiveContains` handles unicode, CJK, emoji correctly |
| Swift Concurrency | Swift 5.9+ | Search debouncing | Task.sleep pattern already used for save debouncing in ClipItemStore |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AttributedString | macOS 12+ | Highlight matched text in search results | Wrap matched subranges in bold/color attributes for visual search highlighting |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| NSEvent local monitor | SwiftUI @FocusState + .onKeyPress | @FocusState is unreliable in MenuBarExtra NSPanel; architecture research confirmed this |
| NSEvent local monitor | SwiftUI .onMoveCommand | Only handles arrow keys, not Enter/Escape/Tab; would need multiple handlers |
| TextField | .searchable() modifier | .searchable() has placement issues in MenuBarExtra popovers; TextField gives full control over layout and focus |
| localizedCaseInsensitiveContains | NSPredicate / regex | Overkill; simple contains is sufficient and faster for substring matching |

## Architecture Patterns

### Recommended Changes to Existing Files

```
PopoverContent.swift (MODIFIED)
├── @State searchText: String          // Local search input
├── @State selectedIndex: Int?         // Keyboard selection
├── @State isSearchFocused: Bool       // Track search field focus
├── TextField("Search history...", text: $searchText)  // NEW: search bar
├── NSEvent local monitor (onAppear/onDisappear)       // NEW: keyboard handling
└── displayItems computed from store   // Filter + section logic

ClipItemStore.swift (MODIFIED)
├── @Published searchQuery: String     // Drives filtering
├── var displayItems: [ClipItem]       // Computed: pinned sort + search filter
└── (existing items, sortItems, etc unchanged)

ItemRow.swift (MODIFIED)
├── isSelected: Bool parameter         // NEW: keyboard selection highlight
└── highlightedContent(query:)         // NEW: attributed string for match highlighting
```

### Pattern 1: Centralized Display List with Search Filtering
**What:** A single computed property on ClipItemStore that produces the display-ready list, handling both pin sorting and search filtering.
**When to use:** When multiple views need the same filtered/sorted data.
**Example:**
```swift
// In ClipItemStore
@Published var searchQuery: String = ""

var displayItems: [ClipItem] {
    let sorted = items  // Already sorted with pinned first by sortItems()
    guard !searchQuery.isEmpty else { return sorted }
    return sorted.filter { item in
        guard !item.isSensitive else { return false }  // Exclude hidden items from search
        if let content = item.content {
            return content.localizedCaseInsensitiveContains(searchQuery)
        }
        // Optionally include source app name in search
        if let appName = item.sourceAppName {
            return appName.localizedCaseInsensitiveContains(searchQuery)
        }
        return false  // Images without text don't match
    }
}
```

### Pattern 2: NSEvent Local Monitor with Lifecycle Management
**What:** Install a keyboard event monitor when the popover appears, remove it when it disappears. Track the monitor reference to prevent leaks.
**When to use:** Keyboard handling inside MenuBarExtra popovers.
**Example:**
```swift
// In PopoverContent
@State private var selectedIndex: Int? = nil
@State private var eventMonitor: Any? = nil

.onAppear {
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        return handleKeyEvent(event)
    }
    // Set initial selection to first item
    if !store.displayItems.isEmpty {
        selectedIndex = 0
    }
}
.onDisappear {
    if let monitor = eventMonitor {
        NSEvent.removeMonitor(monitor)
        eventMonitor = nil
    }
    // Reset state for next open
    selectedIndex = nil
    store.searchQuery = ""
}
```

### Pattern 3: Search Debounce with Task
**What:** Debounce the search query update so filtering doesn't run on every keystroke.
**When to use:** Real-time search with text input.
**Example:**
```swift
// In PopoverContent
@State private var searchText: String = ""
@State private var searchTask: Task<Void, Never>?

// TextField binds to searchText (local), debounce before pushing to store
.onChange(of: searchText) { _, newValue in
    searchTask?.cancel()
    searchTask = Task {
        try? await Task.sleep(nanoseconds: 150_000_000)  // 150ms
        guard !Task.isCancelled else { return }
        store.searchQuery = newValue
        // Reset selection to first result
        selectedIndex = store.displayItems.isEmpty ? nil : 0
    }
}
```

### Pattern 4: Grid-Aware Arrow Key Navigation
**What:** Map arrow keys to movements in a 3-column grid layout.
**When to use:** Keyboard navigation in a grid (not a flat list).
**Example:**
```swift
private func handleArrowKey(_ direction: ArrowDirection) {
    let items = store.displayItems
    guard !items.isEmpty else { return }

    let columns = 3
    let current = selectedIndex ?? -1

    switch direction {
    case .down:
        let next = current + columns
        if next < items.count { selectedIndex = next }
        // Stop at edge -- no wrap
    case .up:
        let next = current - columns
        if next >= 0 { selectedIndex = next }
    case .right:
        let next = current + 1
        if next < items.count { selectedIndex = next }
    case .left:
        let next = current - 1
        if next >= 0 { selectedIndex = next }
    }
}
```

**Important nuance:** The display list is flat (pinned + unpinned merged), but the UI renders them in two separate `LazyVGrid` sections. Arrow navigation must account for the section headers. The simplest approach: flatten the display items into a single ordered array and navigate by flat index, with the selection highlight matching by item ID rather than array index. This avoids the complexity of tracking section boundaries.

### Pattern 5: Attributed String for Search Highlighting
**What:** Highlight the matched search text within item content using bold or color.
**When to use:** When showing search results with visual match indicators.
**Example:**
```swift
func highlightedText(content: String, query: String) -> AttributedString {
    var attributedString = AttributedString(content)
    guard !query.isEmpty else { return attributedString }

    let lowercased = content.lowercased()
    let queryLower = query.lowercased()
    var searchRange = lowercased.startIndex

    while let range = lowercased.range(of: queryLower, range: searchRange..<lowercased.endIndex) {
        // Convert String.Index range to AttributedString range
        let attrStart = AttributedString.Index(range.lowerBound, within: attributedString)!
        let attrEnd = AttributedString.Index(range.upperBound, within: attributedString)!
        attributedString[attrStart..<attrEnd].foregroundColor = Color(red: 0.7, green: 0.4, blue: 0.85)
        attributedString[attrStart..<attrEnd].font = .system(size: 10, weight: .bold)
        searchRange = range.upperBound
    }

    return attributedString
}
```

### Pattern 6: Context-Sensitive Escape Key
**What:** Escape key behavior depends on current state: clear search first, then dismiss.
**Example:**
```swift
case 53:  // Escape
    if !searchText.isEmpty {
        // First press: clear search
        searchText = ""
        store.searchQuery = ""
        selectedIndex = store.displayItems.isEmpty ? nil : 0
        return nil
    } else {
        // Second press: dismiss popover
        // Find the popover panel and close it
        for window in NSApp.windows where window is NSPanel {
            window.close()
        }
        return nil
    }
```

### Anti-Patterns to Avoid
- **Using .searchable() in MenuBarExtra:** The `.searchable()` modifier places the search bar in a toolbar, which behaves unpredictably in MenuBarExtra popovers. The search bar may appear outside the popover or not at all. Use a plain `TextField` with explicit positioning.
- **Using @FocusState for keyboard navigation:** As confirmed in the architecture research, `@FocusState` is unreliable in MenuBarExtra NSPanel windows. The popover's first-responder chain is non-standard. Use `NSEvent.addLocalMonitorForEvents` instead.
- **Filtering in the view body on every render:** Compute `displayItems` once via the store's computed property, not by calling `.filter()` inline in ForEach. The computed property only recalculates when `items` or `searchQuery` changes.
- **Forgetting to remove the event monitor on disappear:** The local event monitor will continue firing even after the popover closes if not removed. This causes "ghost" keyboard handling and potential retain cycle on the closure.
- **Wrapping grid items around on arrow key edges:** User decision explicitly states arrow keys stop at edges. Do not wrap from last item to first or vice versa.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Text highlighting | Manual NSMutableAttributedString with ranges | SwiftUI AttributedString with range-based styling | AttributedString is SwiftUI-native; NSMutableAttributedString requires bridging |
| Keyboard event handling | SwiftUI .onKeyPress / .onMoveCommand chain | NSEvent.addLocalMonitorForEvents | Single handler for all keys; reliable in NSPanel; .onKeyPress is macOS 14+ only and unreliable in MenuBarExtra |
| Search debouncing | Combine publisher chain | Task.sleep cancellation pattern | Project doesn't use Combine; Task pattern matches existing debounce in ClipItemStore |
| Focus tracking between search and list | @FocusState with complex enum | Simple @State Bool (isSearchFieldFocused) checked in event handler | More predictable; @FocusState loses state when popover reopens |

**Key insight:** The NSEvent local monitor is the single most important architectural choice. It provides a unified handler for all keyboard interactions (arrows, Enter, Escape, Tab) and works reliably in the MenuBarExtra popover where SwiftUI's focus system does not.

## Common Pitfalls

### Pitfall 1: Event Monitor Consuming Events Meant for TextField
**What goes wrong:** The NSEvent local monitor intercepts arrow keys and Enter before the search TextField can use them. User can't move cursor in search text or press Enter to submit.
**Why it happens:** Local monitors fire for all key events in the process. The monitor doesn't know whether the TextField or the list area should handle the event.
**How to avoid:** Check focus state before consuming events. When `isSearchFieldFocused` is true, only consume Escape (to clear search) and arrow down (to move focus to list). Let all other keys pass through to the TextField. When list is focused, consume arrow keys, Enter, and Escape.
**Warning signs:** Can't type in search field; cursor doesn't move with arrow keys; Enter in search field copies an item instead of being a no-op.

### Pitfall 2: selectedIndex Becoming Stale After Search Filter Changes
**What goes wrong:** User selects item at index 5, then types a search query that reduces results to 3 items. selectedIndex is now out of bounds, causing a crash or no visible selection.
**Why it happens:** selectedIndex is an integer index into the displayItems array, which changes length when search filters.
**How to avoid:** Reset selectedIndex to 0 (or nil if no results) whenever searchQuery changes. Also clamp selectedIndex on every render: `min(selectedIndex ?? 0, displayItems.count - 1)`.
**Warning signs:** App crashes after searching; selection disappears after typing.

### Pitfall 3: Scroll Position Not Following Keyboard Selection
**What goes wrong:** User arrows down past the visible area but the ScrollView doesn't scroll to keep the selected item visible.
**Why it happens:** SwiftUI ScrollView doesn't automatically scroll to a programmatically-selected item. There's no built-in "scroll to" for items in a LazyVGrid.
**How to avoid:** Use `ScrollViewReader` with `.scrollTo(id, anchor:)`. Each ItemRow gets an `.id(item.id)` anchor. When selectedIndex changes, call `scrollProxy.scrollTo(displayItems[selectedIndex].id, anchor: .center)`.
**Warning signs:** Selection moves off-screen; user has to manually scroll to find the highlighted item.

### Pitfall 4: Double-Installing Event Monitors on Rapid Popover Open/Close
**What goes wrong:** If the popover opens and closes rapidly (e.g., user double-clicks the menu bar icon), `onAppear` fires twice without `onDisappear` between them. Two monitors are installed; keyboard events are handled twice.
**Why it happens:** SwiftUI lifecycle callbacks in MenuBarExtra popovers can be unpredictable.
**How to avoid:** Before installing a new monitor, remove the existing one if present. Use a guard: `if let existing = eventMonitor { NSEvent.removeMonitor(existing) }` before adding a new one.
**Warning signs:** Arrow keys move selection by 2 instead of 1; events fire twice.

### Pitfall 5: Search Filtering Breaks Sectioned Layout
**What goes wrong:** When search is active, some pinned items match and some don't. The "Pinned" section shows a header with zero items, or the section logic breaks because it filters independently from displayItems.
**Why it happens:** PopoverContent currently computes `pinnedItems` and `unpinnedItems` by filtering `store.items` directly, not from a unified display list.
**How to avoid:** When search is active, use `store.displayItems` as a single flat list without sections. Only show Pinned/History sections when search is empty. This matches user expectation: during search, results are a flat ranked list; when search is cleared, the sectioned layout returns.
**Warning signs:** Empty section headers; "Pinned" label showing with no items under it during search.

### Pitfall 6: Preview Pane Not Updating When Selection Changes via Keyboard
**What goes wrong:** The PreviewPane shows the first item or the hovered item, but not the keyboard-selected item. User arrows through items but the preview stays static.
**Why it happens:** PreviewPane currently reads from `hoveredItemID` (set by mouse hover). Keyboard selection uses a separate `selectedIndex` state that PreviewPane doesn't know about.
**How to avoid:** Unify the preview source: `previewItem` should prefer keyboard selection over hover. When `selectedIndex` is set, show that item in preview. When hovering with mouse, temporarily override. Simplest approach: update `hoveredItemID` to the selected item's ID whenever selectedIndex changes.
**Warning signs:** Preview shows wrong item while arrowing through the list.

## Code Examples

### Search TextField with Styling
```swift
// In PopoverContent, placed between PreviewPane and toolbar
HStack(spacing: 6) {
    Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
        .font(.system(size: 12))

    TextField("Search history...", text: $searchText)
        .textFieldStyle(.plain)
        .font(.system(size: 13))
        .onSubmit { }  // Prevent Enter from doing anything in search field

    if !searchText.isEmpty {
        Button {
            searchText = ""
            store.searchQuery = ""
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
        }
        .buttonStyle(.borderless)
    }
}
.padding(.horizontal, 10)
.padding(.vertical, 6)
.background(Color(red: 0.4, green: 0.2, blue: 0.5).opacity(0.1))
.clipShape(RoundedRectangle(cornerRadius: 8))
.padding(.horizontal, 8)
.padding(.top, 4)
```

### Keyboard Selection Highlight on ItemRow
```swift
// In ItemRow, add parameter:
let isSelected: Bool  // NEW

// In the overlay section, add selection ring:
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .stroke(
            isSelected
                ? Color(red: 0.7, green: 0.4, blue: 0.85).opacity(0.8)
                : item.isSensitive
                    ? Color(red: 0.7, green: 0.4, blue: 0.85).opacity(0.4)
                    : Color(red: 0.6, green: 0.35, blue: 0.75).opacity(hoveredItemID == item.id ? 0.4 : 0.1),
            lineWidth: isSelected ? 2 : (item.isSensitive ? 1.5 : 1)
        )
)
```

### Complete Key Event Handler
```swift
private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
    // If search field is focused, only intercept specific keys
    if isSearchFocused {
        switch event.keyCode {
        case 53:  // Escape
            if !searchText.isEmpty {
                searchText = ""
                store.searchQuery = ""
                return nil
            }
            // Dismiss popover
            dismissPopover()
            return nil
        case 125:  // Down arrow -- move focus to list
            isSearchFocused = false
            if selectedIndex == nil && !store.displayItems.isEmpty {
                selectedIndex = 0
            }
            return nil
        case 48:  // Tab
            if event.modifierFlags.contains(.shift) {
                return event  // Shift+Tab from search -- let system handle
            }
            isSearchFocused = false
            if selectedIndex == nil && !store.displayItems.isEmpty {
                selectedIndex = 0
            }
            return nil
        default:
            return event  // Let TextField handle all other keys
        }
    }

    // List is focused
    switch event.keyCode {
    case 125: handleArrowKey(.down); return nil   // Down
    case 126: handleArrowKey(.up); return nil      // Up
    case 124: handleArrowKey(.right); return nil   // Right
    case 123: handleArrowKey(.left); return nil    // Left
    case 36:  // Enter/Return
        copySelectedItem()
        return nil
    case 53:  // Escape
        dismissPopover()
        return nil
    case 48:  // Tab
        if event.modifierFlags.contains(.shift) {
            // Shift+Tab: move focus to search field
            isSearchFocused = true
            return nil
        }
        // Tab: move focus to search field
        isSearchFocused = true
        return nil
    default:
        return event  // Pass through unhandled keys
    }
}
```

### No Results Empty State
```swift
if store.displayItems.isEmpty && !store.searchQuery.isEmpty {
    VStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
            .font(.title2)
            .foregroundStyle(.tertiary)
        Text("No results for \"\(store.searchQuery)\"")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        Text("Try a different search term")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
}
```

## Discretion Recommendations

For the areas marked as Claude's Discretion in CONTEXT.md:

| Area | Recommendation | Rationale |
|------|----------------|-----------|
| Search field visual treatment | Magnifying glass icon left, clear (x) button right, subtle material background | Matches macOS native search field conventions; clear button only shows when text is present |
| What gets searched | Text content AND source app name | Low cost (one extra `contains` check), high value (user can search "Safari" to find web copies) |
| No-results empty state | Centered magnifying glass icon + "No results for [query]" + "Try a different search term" | Standard pattern; prevents confusion from blank list |
| Typing while list is focused | Ignore keystrokes; require Tab to reach search field | User decision says "explicit focus" -- typing should not auto-redirect. This keeps arrow navigation unambiguous. |
| Preview pane update timing | Immediate (no debounce) | At 500 items, preview lookup by ID is O(1) from the display array; no performance reason to debounce. Immediate feels more responsive. |
| Search debounce timing | 150ms | Fast enough to feel "real-time" per SRCH-02, slow enough to avoid filtering on every keystroke during fast typing. Lower than save debounce (500ms) because search is lightweight. |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| .searchable() for all search UIs | TextField with manual layout for constrained contexts | Always true for MenuBarExtra | .searchable() assumes standard window/NavigationStack; TextField works everywhere |
| @FocusState for keyboard handling | NSEvent.addLocalMonitorForEvents | Known issue since MenuBarExtra introduction (macOS 13) | @FocusState loses state in NSPanel windows; NSEvent monitors are reliable |
| Separate selectedItem state | Unified hoveredItemID for both mouse and keyboard | Current recommendation | Simplifies preview logic; one source of truth for "active" item |

## Open Questions

1. **Focus tracking accuracy between TextField and list**
   - What we know: NSEvent local monitor fires for all key events regardless of which view has first-responder status. We need to know if the search field has focus.
   - What's unclear: Whether SwiftUI TextField in a MenuBarExtra properly reports first-responder status. The `isSearchFocused` state may need to be synchronized manually (set true on TextField tap, false on list area tap/arrow navigation).
   - Recommendation: Use a combination of `.onEditingChanged` callback on TextField and manual state tracking in the event handler. Test thoroughly. If synchronization is unreliable, consider wrapping the TextField in an NSViewRepresentable that exposes a reliable focus callback.

2. **ScrollViewReader behavior with two separate LazyVGrid sections**
   - What we know: ScrollViewReader's `.scrollTo()` works with `.id()` anchors. Each ItemRow can have `.id(item.id)`.
   - What's unclear: Whether `.scrollTo()` works correctly when the target item is inside a nested LazyVGrid within a LazyVStack. May need the `.id()` on the outer container or on individual grid cells.
   - Recommendation: Place `.id(item.id)` on each ItemRow directly. Test with both pinned and unpinned sections. If scrollTo fails across section boundaries, consider flattening to a single LazyVGrid during keyboard navigation.

3. **KBNAV-04 scope boundary with Phase 9**
   - What we know: KBNAV-04 says "When popover opens via hotkey, the search field is focused." The global hotkey is Phase 9. The user decided Phase 8 opens with focus on the first list item.
   - What's unclear: Whether KBNAV-04 should be partially implemented in Phase 8 (build the infrastructure) or entirely deferred to Phase 9.
   - Recommendation: Phase 8 builds the `isSearchFocused` state and the Tab/Shift+Tab focus toggle. Phase 9 sets `isSearchFocused = true` when the popover opens via hotkey. This way KBNAV-04's infrastructure exists in Phase 8 but the hotkey-specific behavior ships with Phase 9.

## Sources

### Primary (HIGH confidence)
- Existing codebase: PopoverContent.swift, ClipItemStore.swift, ClipItem.swift, ItemRow.swift, PreviewPane.swift -- current architecture and patterns
- v1.2 Architecture research (.planning/research/ARCHITECTURE.md) -- NSEvent local monitor pattern, displayItems computed property, keyboard navigation approach
- v1.2 Pitfalls research (.planning/research/PITFALLS.md) -- keyboard nav focus conflicts, search performance traps
- Apple NSEvent.addLocalMonitorForEvents documentation -- event interception and consumption patterns
- Apple AttributedString documentation -- range-based text styling for search highlighting

### Secondary (MEDIUM confidence)
- v1.2 Stack research (.planning/research/STACK.md) -- TextField vs .searchable() tradeoffs, @FocusState limitations in MenuBarExtra
- v1.2 Features research (.planning/research/FEATURES.md) -- search debounce recommendations, keyboard navigation patterns from competitors (Maccy, Paste)
- Phase 7 Research (.planning/phases/07-favorites-history-scale/07-RESEARCH.md) -- sectioned layout pattern, pin sorting approach

### Tertiary (LOW confidence)
- None -- all findings verified against existing codebase and prior research

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- using only built-in Apple frameworks already in the project; no new dependencies
- Architecture: HIGH -- patterns directly derived from existing codebase and verified v1.2 architecture research
- Pitfalls: HIGH -- keyboard focus issues are well-documented in prior research; search performance is trivial at 500 items

**Research date:** 2026-02-22
**Valid until:** 2026-03-22 (stable -- no external dependencies, all built-in Apple frameworks)
