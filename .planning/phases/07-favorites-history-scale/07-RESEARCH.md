# Phase 7: Favorites + History Scale - Research

**Researched:** 2026-02-21
**Domain:** SwiftUI data model evolution, NSCache image caching, debounced persistence, context menus
**Confidence:** HIGH

## Summary

Phase 7 adds two interrelated features to Copyhog: (1) a favorites/pin system that lets users protect important clipboard items from auto-purge, and (2) scaling the history from 20 to 500 items without performance degradation. The current codebase has a clean foundation -- `ClipItem` is a `Codable` struct, `ClipItemStore` is a `@MainActor ObservableObject` with synchronous JSON persistence, and the UI uses `LazyVGrid` for item display.

The core technical challenges are: adding an `isPinned` boolean to `ClipItem` with backward-compatible decoding, splitting the UI into pinned/unpinned sections, implementing NSCache-based thumbnail caching so 500 image thumbnails don't each trigger disk I/O on scroll, replacing synchronous `save()` with debounced background writes, and updating the purge logic to skip pinned items.

**Primary recommendation:** Add `isPinned: Bool` to ClipItem with `decodeIfPresent` defaulting to false, wrap ImageStore.loadImage with an NSCache layer, debounce saves using a Task-based timer pattern, and split PopoverContent's ForEach into two sections (pinned at top, history below).

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FAV-01 | User can pin/favorite a clipboard item via context menu or keyboard shortcut | Context menu pattern already exists in ItemRow; add "Pin" action + toggle `isPinned` on ClipItem |
| FAV-02 | Pinned items displayed in dedicated section at top of history list | Split LazyVGrid ForEach into two sections with section headers |
| FAV-03 | Pinned items never auto-purged regardless of history limit | Purge logic in `add()` must filter to only remove unpinned items |
| FAV-04 | User can unpin an item to return it to normal history behavior | Toggle `isPinned` back to false; same context menu action |
| HIST-01 | History limit raised to 500 items | Update `@AppStorage("historyLimit")` range to support up to 500; update settings picker |
| HIST-02 | Persistence performant at 500 items (debounced saves, no UI stutter) | Debounced save with Task.sleep pattern; encode on background thread |
| HIST-03 | Thumbnail images cached in memory (NSCache) for smooth scrolling | NSCache wrapper around ImageStore.loadImage; automatic eviction under memory pressure |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | macOS 14+ | UI framework (LazyVGrid, context menus) | Already in use; LazyVGrid handles 500 items natively |
| Foundation NSCache | macOS 14+ | In-memory thumbnail cache | Thread-safe, auto-evicts under memory pressure, zero dependencies |
| Swift Concurrency | Swift 5.9+ | Debounced background saves | Task.sleep pattern for debouncing; nonisolated functions for off-main encoding |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @AppStorage | SwiftUI | Persist historyLimit setting | Already used for historyLimit; extend picker range |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| NSCache | Dictionary<UUID, NSImage> | NSCache auto-evicts under memory pressure; Dictionary does not |
| Task.sleep debounce | Combine debounce | Project doesn't use Combine; Task.sleep is simpler and already fits the async pattern |
| JSON file | SQLite/SwiftData | Overkill for 500 items; JSON is already working and fast enough with debouncing |

## Architecture Patterns

### Data Model Evolution
```
ClipItem (updated)
├── id: UUID
├── type: ItemType
├── content: String?
├── thumbnailPath: String?
├── filePath: String?
├── timestamp: Date
├── isSensitive: Bool
├── sourceAppBundleID: String?
├── sourceAppName: String?
└── isPinned: Bool          // NEW - defaults to false
```

### Pattern 1: Backward-Compatible Codable Field Addition
**What:** Add `isPinned` to ClipItem with `decodeIfPresent` defaulting to false so existing items.json loads without migration.
**When to use:** Any time you add a new field to a persisted Codable struct.
**Example:**
```swift
// In ClipItem.init(from decoder:)
isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
```

### Pattern 2: NSCache Thumbnail Wrapper
**What:** A cache layer in ImageStore that stores loaded NSImages keyed by relative path, avoiding repeated disk reads.
**When to use:** When the same thumbnails are loaded repeatedly during scroll.
**Example:**
```swift
// Source: Apple NSCache documentation + SwiftUI caching patterns
final class ImageStore: @unchecked Sendable {
    private let thumbnailCache = NSCache<NSString, NSImage>()

    init() {
        // ...existing init...
        thumbnailCache.countLimit = 200  // Keep up to 200 thumbnails in memory
    }

    func loadImage(relativePath: String) -> NSImage? {
        let key = relativePath as NSString
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        let url = baseDirectory.appendingPathComponent(relativePath)
        guard let image = NSImage(contentsOf: url) else { return nil }
        thumbnailCache.setObject(image, forKey: key)
        return image
    }

    func invalidateCache(relativePath: String) {
        thumbnailCache.removeObject(forKey: relativePath as NSString)
    }
}
```

### Pattern 3: Debounced Save with Task
**What:** Replace synchronous save() with a debounced version that waits 0.5s after the last mutation before writing.
**When to use:** When multiple rapid mutations (add, pin, unpin) would otherwise trigger many disk writes.
**Example:**
```swift
// In ClipItemStore
private var saveTask: Task<Void, Never>?

private func scheduleSave() {
    saveTask?.cancel()
    saveTask = Task { [weak self] in
        do {
            try await Task.sleep(for: .milliseconds(500))
            await self?.performSave()
        } catch {
            // Cancelled -- a newer save is pending
        }
    }
}

private func performSave() {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let itemsCopy = items  // Capture current state
    Task.detached { [storeURL] in
        do {
            let data = try encoder.encode(itemsCopy)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            print("[ClipItemStore] Save failed: \(error)")
        }
    }
}
```

### Pattern 4: Pinned-Aware Purge Logic
**What:** When items exceed maxItems, only remove unpinned items (oldest first).
**Example:**
```swift
func add(_ item: ClipItem) {
    items.insert(item, at: 0)

    // Only purge unpinned items
    while items.count > maxItems {
        if let lastUnpinnedIndex = items.lastIndex(where: { !$0.isPinned }) {
            let removed = items.remove(at: lastUnpinnedIndex)
            cleanupImages(for: removed)
        } else {
            break  // All items are pinned; don't purge
        }
    }

    scheduleSave()
}
```

### Pattern 5: Sectioned UI Layout
**What:** Split the grid into Pinned and History sections.
**Example:**
```swift
ScrollView {
    LazyVStack(spacing: 0) {
        // Pinned section
        let pinnedItems = store.items.filter { $0.isPinned }
        if !pinnedItems.isEmpty {
            HStack {
                Label("Pinned", systemImage: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(pinnedItems) { item in
                    ItemRow(item: item, /* ... */)
                }
            }
            .padding(.horizontal, 8)
        }

        // History section
        let unpinnedItems = store.items.filter { !$0.isPinned }
        if !unpinnedItems.isEmpty {
            HStack {
                Label("History", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(unpinnedItems) { item in
                    ItemRow(item: item, /* ... */)
                }
            }
            .padding(.horizontal, 8)
        }
    }
}
```

### Anti-Patterns to Avoid
- **Filtering in the view body without caching:** Computing `items.filter { $0.isPinned }` every render is fine for 500 items (negligible cost), but do NOT create new arrays via `.sorted()` chains in the body -- keep items pre-sorted in the store.
- **Using `.id()` modifier on ForEach children:** This breaks lazy loading behavior and forces all views to instantiate. Let Identifiable conformance handle identity.
- **Storing NSImage in @State:** When items scroll out of view, SwiftUI may not release NSImage from @State properly. Use NSCache in ImageStore instead, which handles memory pressure automatically.
- **Synchronous JSON encoding of 500 items on main thread:** At 500 items with image paths, JSON encoding can take 10-50ms. Encode on a detached task.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Image memory cache | Custom Dictionary with manual eviction | NSCache | Thread-safe, auto-evicts under memory pressure, tested by Apple |
| Debounce timer | DispatchWorkItem + manual cancellation | Task.sleep + Task cancellation | Cleaner, automatic cancellation, no retain cycle risk |
| Data migration | Manual JSON version checking | `decodeIfPresent` with defaults | Codable handles missing keys gracefully; no migration code needed |

**Key insight:** NSCache is purpose-built for this exact use case. It handles memory pressure automatically, is thread-safe without locks, and requires zero configuration beyond optional count/cost limits.

## Common Pitfalls

### Pitfall 1: Forgetting to save on app termination during debounce window
**What goes wrong:** User pins an item, debounce timer hasn't fired yet, app terminates -- change is lost.
**Why it happens:** Debounced saves delay writes; app termination cancels pending tasks.
**How to avoid:** Add an immediate `performSave()` call in `applicationWillTerminate` or when the store is being deallocated. Also save immediately for critical operations (pin/unpin).
**Warning signs:** "I pinned something but it's gone after restart."

### Pitfall 2: Pinned items consuming all slots
**What goes wrong:** User pins 500 items, then no new items can be added because purge can't remove anything.
**Why it happens:** Purge logic skips pinned items; if all items are pinned, nothing can be purged.
**How to avoid:** The purge loop already handles this with the `break` when no unpinned items remain. Optionally, cap pinned items at a reasonable number (e.g., 50) and show a warning.
**Warning signs:** History stops growing despite new clipboard copies.

### Pitfall 3: LazyVGrid identity issues with filtered arrays
**What goes wrong:** Filtering items into pinned/unpinned arrays can cause SwiftUI to lose track of items when pin state changes, leading to animation glitches.
**Why it happens:** SwiftUI uses Identifiable ID to track items across renders; filtered arrays change indices but IDs stay stable.
**How to avoid:** ClipItem already conforms to Identifiable with UUID -- this is sufficient. Avoid using `.id()` modifier on top. Use `withAnimation` when toggling pin state.
**Warning signs:** Items flicker or jump when pinned/unpinned.

### Pitfall 4: NSCache eviction causing visible thumbnail reload flicker
**What goes wrong:** Under memory pressure, NSCache evicts thumbnails. When user scrolls back, there's a brief blank state while reloading from disk.
**Why it happens:** NSCache eviction is automatic and not predictable.
**How to avoid:** Use a placeholder (e.g., `Image(systemName: "photo")`) which is already in place in the current `imageCardContent`. The existing fallback handles this gracefully.
**Warning signs:** Thumbnails briefly show placeholder icon when scrolling quickly through large history.

### Pitfall 5: History settings picker not reflecting new range
**What goes wrong:** Settings picker still shows 10-50 range after raising limit to 500.
**Why it happens:** SettingsMenu hardcodes picker options.
**How to avoid:** Update the picker to include higher values (100, 200, 500) while keeping lower options for users who want them.

## Code Examples

### Adding isPinned to ClipItem
```swift
struct ClipItem: Codable, Identifiable {
    let id: UUID
    let type: ItemType
    let content: String?
    let thumbnailPath: String?
    let filePath: String?
    let timestamp: Date
    let isSensitive: Bool
    let sourceAppBundleID: String?
    let sourceAppName: String?
    var isPinned: Bool  // NEW -- mutable for toggling

    enum CodingKeys: String, CodingKey {
        case id, type, content, thumbnailPath, filePath, timestamp, isSensitive
        case sourceAppBundleID, sourceAppName, isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // ...existing decoding...
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}
```

### Pin/Unpin in ClipItemStore
```swift
func togglePin(id: UUID) {
    guard let index = items.firstIndex(where: { $0.id == id }) else { return }
    items[index].isPinned.toggle()
    // Re-sort: pinned items first, then by timestamp
    items.sort { lhs, rhs in
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
        return lhs.timestamp > rhs.timestamp
    }
    scheduleSave()
}
```

### Context Menu Pin Action in ItemRow
```swift
.contextMenu {
    Button {
        onTogglePin?()
    } label: {
        Label(
            item.isPinned ? "Unpin" : "Pin",
            systemImage: item.isPinned ? "pin.slash" : "pin"
        )
    }

    if !item.isSensitive {
        Button {
            onMarkSensitive?()
        } label: {
            Label("Mark as Sensitive", systemImage: "lock.shield")
        }
    }

    Button(role: .destructive) {
        onDelete?()
    } label: {
        Label("Delete", systemImage: "trash")
    }
}
```

### Updated Settings Picker for History Size
```swift
private var historySizePicker: some View {
    Picker("History Size", selection: $historyLimit) {
        Text("20").tag(20)
        Text("50").tag(50)
        Text("100").tag(100)
        Text("200").tag(200)
        Text("500").tag(500)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Synchronous JSON save on every mutation | Debounced save with Task.sleep | Swift 5.5+ (async/await) | Prevents UI freezes with frequent mutations |
| Dictionary for image caching | NSCache with countLimit | Always preferred | Auto memory management, thread safety |
| Single flat list | Sectioned LazyVStack with LazyVGrid sections | SwiftUI pattern | Clean separation of pinned vs history |

**Deprecated/outdated:**
- Combine `debounce` operator for non-reactive contexts: Task.sleep is simpler when you're already in async Swift code
- UICollectionView/NSCollectionView: Not needed; SwiftUI LazyVGrid handles 500 items well

## Open Questions

1. **Maximum pinned items cap?**
   - What we know: No explicit requirement to cap pinned items
   - What's unclear: Should there be a limit (e.g., 50) to prevent users from pinning everything?
   - Recommendation: Don't cap for now; the purge logic handles the edge case gracefully by stopping when only pinned items remain

2. **Pin indicator visual design?**
   - What we know: Pinned items need to be visually distinct in their dedicated section
   - What's unclear: Exact visual treatment (pin icon overlay? different border color?)
   - Recommendation: Add a small pin icon overlay (top-left corner) on pinned item cards, similar to the multi-select checkbox placement

## Sources

### Primary (HIGH confidence)
- Apple NSCache documentation -- thread safety, auto-eviction behavior
- [Apple Developer: Creating performant scrollable stacks](https://developer.apple.com/documentation/swiftui/creating-performant-scrollable-stacks) -- LazyVGrid best practices
- Existing codebase: ClipItem.swift, ClipItemStore.swift, PopoverContent.swift, ItemRow.swift, ImageStore.swift -- current architecture

### Secondary (MEDIUM confidence)
- [Tips and Considerations for Using Lazy Containers in SwiftUI](https://fatbobman.com/en/posts/tips-and-considerations-for-using-lazy-containers-in-swiftui/) -- identity issues, memory release patterns
- [Yielding and debouncing in Swift Concurrency](https://swiftwithmajid.com/2025/02/18/yielding-and-debouncing-in-swift-concurrency/) -- Task.sleep debounce pattern
- [NSCache image caching patterns](https://www.createwithswift.com/image-caching-in-swiftui/) -- countLimit, thread safety confirmation

### Tertiary (LOW confidence)
- None -- all findings verified with multiple sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- using only built-in Apple frameworks already in the project
- Architecture: HIGH -- patterns directly derived from existing codebase structure
- Pitfalls: HIGH -- based on verified SwiftUI lazy container behavior and common persistence patterns

**Research date:** 2026-02-21
**Valid until:** 2026-03-21 (stable -- no fast-moving dependencies)
