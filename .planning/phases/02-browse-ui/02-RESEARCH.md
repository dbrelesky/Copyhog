# Phase 2: Browse UI - Research

**Researched:** 2026-02-21
**Domain:** SwiftUI popover layout — item list with hover-driven preview pane, macOS 14+
**Confidence:** HIGH

## Summary

Phase 2 transforms the existing `PopoverContent` view into a two-section layout: a preview pane at the top showing full-size content of the hovered item, and a scrollable item list at the bottom with 64x64 thumbnails (images) or 2-line text snippets plus relative timestamps. The hover interaction drives the preview — when the user hovers over a row, the preview pane updates. An empty state is shown when no items exist.

The existing codebase already has a basic `PopoverContent.swift` with a List, thumbnail loading via `ImageStore.loadImage(relativePath:)`, and a simple empty state. The deployment target is macOS 14.0, which means we have access to `ContentUnavailableView` (macOS 14+), `onContinuousHover` (macOS 13+), and all modern SwiftUI layout APIs. The popover frame is already set to 360x480 via `MenuBarExtra` with `.window` style.

The key technical challenge is the `.onHover` modifier's known unreliability on macOS — it occasionally fails to fire the exit callback at high cursor velocity. For a list of 20 items with hover-to-preview, this needs careful handling. The recommended approach is to use `.onHover` on each row (simple and sufficient for this scale) but track the hovered item ID as `@State` on the parent view, so only one item is "active" at a time. If a new row fires `onHover(true)`, it replaces the previous selection, making stale hover state a non-issue.

**Primary recommendation:** Refactor `PopoverContent` into a `VStack` with a fixed-height preview pane on top and a `List` of item rows below. Use `@State private var hoveredItemID: UUID?` to track which row is hovered, and `.onHover` on each row to update it. Load full-size images on-demand only for the hovered/previewed item. Use `ContentUnavailableView` for the empty state.

## Standard Stack

### Core
| Library / API | Version | Purpose | Why Standard |
|---------------|---------|---------|--------------|
| SwiftUI | macOS 14+ | All UI — VStack layout, List, Image, Text, onHover | Already in use, native framework |
| AppKit (NSImage) | macOS 14+ | Image loading from disk via `ImageStore` | Already wired up, `Image(nsImage:)` bridge |

### Supporting
| Library / API | Version | Purpose | When to Use |
|---------------|---------|---------|-------------|
| ContentUnavailableView | macOS 14+ | Empty state display | When `store.items.isEmpty` |
| Text(_, style: .relative) | macOS 14+ | Relative timestamps ("2 min ago") | Already used in current PopoverContent |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| List for item rows | ScrollView + LazyVStack | List has better view recycling and memory performance; LazyVStack gives more styling control but worse performance. With max 20 items, difference is negligible — List is simpler |
| .onHover per row | .onContinuousHover with coordinate math | onContinuousHover gives pointer coordinates but requires manual hit-testing against row frames; overkill for discrete row hover |
| ContentUnavailableView | Custom VStack empty state | ContentUnavailableView is the platform-standard pattern, provides consistent look, supports system image and description |

**Installation:**
No external packages required. All APIs are system frameworks already in use.

## Architecture Patterns

### Recommended View Structure
```
PopoverContent (360x480)
├── PreviewPane (top, fixed height ~200pt)
│   ├── Full-size image (aspect-fit) when hoveredItem is image
│   ├── Full text (scrollable) when hoveredItem is text
│   └── Placeholder when nothing hovered / no items
├── Divider
└── ItemList (bottom, fills remaining space)
    └── List of ItemRow views
        ├── 64x64 thumbnail or doc.text icon
        ├── 2-line content snippet or filename
        └── Relative timestamp (trailing)
```

### Pattern 1: Hover-Driven Preview with @State
**What:** Parent view owns `@State var hoveredItemID: UUID?`, each row uses `.onHover` to set it.
**When to use:** When hover on one element should update a different part of the UI.
**Example:**
```swift
struct PopoverContent: View {
    @EnvironmentObject var store: ClipItemStore
    @State private var hoveredItemID: UUID?

    private var previewItem: ClipItem? {
        if let id = hoveredItemID {
            return store.items.first { $0.id == id }
        }
        return store.items.first  // Default to most recent
    }

    var body: some View {
        if store.items.isEmpty {
            ContentUnavailableView(
                "No Clips Yet",
                systemImage: "clipboard",
                description: Text("Copy text or take a screenshot to get started")
            )
        } else {
            VStack(spacing: 0) {
                PreviewPane(item: previewItem, imageStore: store.imageStore)
                    .frame(height: 200)
                Divider()
                ItemList(
                    items: store.items,
                    hoveredItemID: $hoveredItemID,
                    imageStore: store.imageStore
                )
            }
        }
    }
}
```

### Pattern 2: Item Row with onHover
**What:** Each row applies `.onHover` to update the parent's hovered ID.
**When to use:** For each row in the item list.
**Example:**
```swift
struct ItemRow: View {
    let item: ClipItem
    let imageStore: ImageStore
    @Binding var hoveredItemID: UUID?

    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail
            if item.type == .image,
               let thumbPath = item.thumbnailPath,
               let nsImage = imageStore.loadImage(relativePath: thumbPath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if item.type == .text {
                Image(systemName: "doc.text")
                    .frame(width: 64, height: 64)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Content snippet
            VStack(alignment: .leading, spacing: 2) {
                if let content = item.content {
                    Text(content)
                        .lineLimit(2)
                        .font(.caption)
                }
            }

            Spacer()

            // Timestamp
            Text(item.timestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            hoveredItemID = hovering ? item.id : nil
        }
    }
}
```

### Pattern 3: Preview Pane with Conditional Content
**What:** Shows full-size image or full text based on the previewed item's type.
**When to use:** Top section of the popover.
**Example:**
```swift
struct PreviewPane: View {
    let item: ClipItem?
    let imageStore: ImageStore

    var body: some View {
        Group {
            if let item {
                if item.type == .image,
                   let filePath = item.filePath,
                   let nsImage = imageStore.loadImage(relativePath: filePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let content = item.content {
                    ScrollView {
                        Text(content)
                            .font(.body)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
```

### Anti-Patterns to Avoid
- **Loading full-size images for every row:** Only load the full image for the currently previewed item. Rows use 64x64 thumbnails from `thumbnailPath`, not `filePath`.
- **Using @Binding for preview item instead of ID:** Pass the hovered ID, not the entire item — avoids unnecessary view redraws when item properties have not changed.
- **Nested ScrollViews without fixed frames:** The List already scrolls. Do not wrap it in another ScrollView. The preview pane's text ScrollView is fine because it has a fixed frame height.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Empty state UI | Custom VStack with icon + text | `ContentUnavailableView` (macOS 14+) | Platform-standard, accessible, localization-ready |
| Relative timestamps | Custom "time ago" formatter | `Text(date, style: .relative)` | Already used in codebase, auto-updates, localized |
| Image aspect-fit in preview | Manual geometry calculation | `.resizable().aspectRatio(contentMode: .fit)` | SwiftUI handles this natively |
| View recycling in list | Custom lazy loading | `List` with `Identifiable` items | List recycles views automatically |

**Key insight:** This phase is pure SwiftUI layout — every requirement maps to a built-in SwiftUI view or modifier. No custom infrastructure is needed.

## Common Pitfalls

### Pitfall 1: onHover Exit Not Firing
**What goes wrong:** `.onHover` sometimes fails to call the closure with `false` when the cursor exits at high velocity, leaving a row falsely marked as hovered.
**Why it happens:** Known SwiftUI bug on macOS — the tracking area exit event is missed at high cursor speeds.
**How to avoid:** Use the "last writer wins" pattern — when a new row fires `onHover(true)`, it overwrites `hoveredItemID` regardless of whether the previous row fired `onHover(false)`. This means at most one false positive (the last exited row), which is immediately replaced when hovering another row.
**Warning signs:** Preview pane not updating, or updating to wrong item after fast mouse movement.

### Pitfall 2: Full Image Loaded for Every Row
**What goes wrong:** Loading full-size images (potentially multi-MB screenshots) for each row causes jank and high memory use.
**Why it happens:** Using `filePath` instead of `thumbnailPath` in the row view, or preloading all full images.
**How to avoid:** Rows MUST use `thumbnailPath` (64x64). Only the `PreviewPane` loads from `filePath`, and only for the single currently-previewed item.
**Warning signs:** Slow popover open, stuttery scrolling, high memory in Activity Monitor.

### Pitfall 3: Thumbnail Size Mismatch
**What goes wrong:** Requirements say 64x64 thumbnails, but current code renders thumbnails at 120x120 in the view.
**Why it happens:** Phase 1 used 120x120 frame size for thumbnails. Phase 2 requires 64x64.
**How to avoid:** Change the thumbnail `frame(width:height:)` to 64x64 in the row view. The underlying thumbnail file is already generated at 64x64 by `ImageStore.generateThumbnail`.
**Warning signs:** Thumbnails look blurry at 120pt because the source is only 64px.

### Pitfall 4: MenuBarExtra Frame Duplication
**What goes wrong:** The `.frame(width: 360, height: 480)` is applied both in `PopoverContent` and in `CopyhogApp` on the `.environmentObject` call.
**Why it happens:** Phase 1 added frame in both places.
**How to avoid:** Keep frame in one place only — preferably in `PopoverContent` body, remove from `CopyhogApp`.
**Warning signs:** Unexpected double-padding or layout issues.

### Pitfall 5: List Row Insets and Styling
**What goes wrong:** Default `List` row insets and styling (disclosure indicators, selection highlight) interfere with the clean browse UI.
**Why it happens:** macOS `List` has default insets and behaviors that differ from iOS.
**How to avoid:** Use `.listRowInsets(EdgeInsets())` to remove default padding if needed, and `.listStyle(.plain)` for minimal chrome.
**Warning signs:** Rows have unexpected left/right padding, separator lines look wrong.

## Code Examples

### Complete PopoverContent Refactor
```swift
// Source: Synthesized from SwiftUI documentation patterns
struct PopoverContent: View {
    @EnvironmentObject var store: ClipItemStore
    @State private var hoveredItemID: UUID?

    private var previewItem: ClipItem? {
        if let id = hoveredItemID {
            return store.items.first { $0.id == id }
        }
        return store.items.first
    }

    var body: some View {
        Group {
            if store.items.isEmpty {
                ContentUnavailableView(
                    "No Clips Yet",
                    systemImage: "clipboard",
                    description: Text("Copy text or take a screenshot to get started")
                )
            } else {
                VStack(spacing: 0) {
                    PreviewPane(item: previewItem, imageStore: store.imageStore)
                        .frame(height: 200)

                    Divider()

                    List(store.items) { item in
                        ItemRow(
                            item: item,
                            imageStore: store.imageStore,
                            hoveredItemID: $hoveredItemID
                        )
                    }
                    .listStyle(.plain)
                }
            }
        }
        .frame(width: 360, height: 480)
    }
}
```

### ContentUnavailableView Empty State
```swift
// Source: Apple Developer Documentation — ContentUnavailableView (macOS 14+)
ContentUnavailableView(
    "No Clips Yet",
    systemImage: "clipboard",
    description: Text("Copy text or take a screenshot to get started")
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Custom empty state VStack | `ContentUnavailableView` | macOS 14 / WWDC 2023 | Standard platform pattern, accessible |
| `RelativeDateTimeFormatter` | `Text(date, style: .relative)` | SwiftUI 2 (macOS 11) | Auto-updating, simpler |
| `NSTrackingArea` for hover | `.onHover` / `.onContinuousHover` | macOS 12 / macOS 13 | Declarative, but with known exit-callback bug |

**Deprecated/outdated:**
- Manual NSTrackingArea setup for hover detection — use SwiftUI `.onHover` instead
- Custom empty state views — `ContentUnavailableView` is the standard since macOS 14

## Open Questions

1. **Default preview when nothing is hovered**
   - What we know: When the popover opens, no row is hovered yet
   - What's unclear: Should the preview show the most recent item by default, or be blank?
   - Recommendation: Default to most recent item (first in list) — this is what clipboard managers like Maccy and Paste do. The code example above implements this.

2. **Preview pane height ratio**
   - What we know: Total frame is 480pt. Need space for both preview and scrollable list.
   - What's unclear: Exact split ratio.
   - Recommendation: 200pt for preview, ~280pt for list. This gives ~4-5 visible rows at 64pt row height, which is comfortable for browsing.

3. **Image text items in preview — styling**
   - What we know: Text items should show "full text" in the preview pane.
   - What's unclear: Font size, padding, max lines, monospace vs proportional.
   - Recommendation: Use `.font(.body)` with `.padding(12)` in a ScrollView. Proportional font (system default) for readability.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — `ContentUnavailableView` (macOS 14+)
- Apple Developer Documentation — `onHover(perform:)` modifier
- Apple Developer Documentation — `Text(date, style: .relative)`
- Existing codebase — `PopoverContent.swift`, `ClipItem.swift`, `ImageStore.swift`, `ClipItemStore.swift`

### Secondary (MEDIUM confidence)
- [Hacking with Swift — How to detect the user hovering over a view](https://www.hackingwithswift.com/quick-start/swiftui/how-to-detect-the-user-hovering-over-a-view) — onHover patterns
- [Nil Coalescing — Tracking hover location in SwiftUI](https://nilcoalescing.com/blog/TrackingHoverLocationInSwiftUI/) — onContinuousHover details
- [GitHub Gist — Reliable SwiftUI mouse hover](https://gist.github.com/importRyan/c668904b0c5442b80b6f38a980595031) — onHover exit bug documentation
- [Fat Bob Man — List or LazyVStack](https://fatbobman.com/en/posts/list-or-lazyvstack/) — List vs LazyVStack performance
- [STRV — SwiftUI: List vs LazyVStack](https://www.strv.com/blog/swiftui-list-vs-lazyvstack) — Performance comparison
- [Antoine van der Lee — ContentUnavailableView](https://www.avanderlee.com/swiftui/contentunavailableview-handling-empty-states/) — Empty state patterns

### Tertiary (LOW confidence)
- None — all findings verified with official documentation or multiple credible sources.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all system frameworks already in use, no new dependencies
- Architecture: HIGH — standard SwiftUI layout patterns, well-documented
- Pitfalls: HIGH — onHover bug is widely documented, thumbnail/image loading patterns are well-known

**Research date:** 2026-02-21
**Valid until:** 2026-03-21 (stable — SwiftUI macOS 14 APIs are mature)
