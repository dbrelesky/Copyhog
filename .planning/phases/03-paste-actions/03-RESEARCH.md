# Phase 3: Paste Actions - Research

**Researched:** 2026-02-21
**Domain:** macOS pasteboard writing, SwiftUI gestures, drag-and-drop (Transferable / NSItemProvider)
**Confidence:** HIGH

## Summary

Phase 3 closes the loop: captured items become actionable. The three capabilities are single-click copy (write one item to NSPasteboard.general), multi-select batch paste (write multiple file URLs to the pasteboard), and drag-out (items draggable from the popover into target apps).

All three rely on the same foundation: `NSPasteboard.general`. Single-click copy is straightforward (`clearContents()` + `setString` or `setData`). Multi-select batch paste uses `writeObjects(_:)` with an array of `NSURL` objects cast as `NSPasteboardWriting`. Drag-out on macOS SwiftUI uses the `.draggable()` modifier (macOS 13+) with the `Transferable` protocol, requiring both a `FileRepresentation` and a `ProxyRepresentation` (URL proxy) to work across apps like Finder, Slack, and Figma. A critical integration concern is that writing to `NSPasteboard.general` from our own app will trigger the `ClipboardObserver` -- the existing `skipNextChange()` flag on `ClipboardObserver` already handles this pattern and must be called before every paste-back write.

**Primary recommendation:** Use `NSPasteboard.general` directly for single/batch copy (not SwiftUI Clipboard API), use `.draggable()` + `Transferable` for drag-out, and keep `.onTapGesture` on a parent container while `.draggable` lives on the inner view to avoid gesture conflicts.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PASTE-01 | Single-clicking an item row copies it to the system clipboard | NSPasteboard.general `clearContents()` + `setString`/`setData` for text/image; `skipNextChange()` on ClipboardObserver to prevent re-capture; `.onTapGesture` or `.simultaneousGesture` on ItemRow |
| PASTE-02 | Multi-select mode toggleable via button, enables checkboxes on rows | `@State isMultiSelectActive` bool, `@State selectedItems: Set<UUID>`, conditional Toggle/checkbox overlay in ItemRow, toolbar button to toggle mode |
| PASTE-03 | "Copy N items" button writes selected image file URLs as NSPasteboardItem array to pasteboard | `NSPasteboard.general.clearContents()` + `writeObjects(urls as [NSPasteboardWriting])` where urls are `NSURL` objects pointing to image files in App Support; text items concatenated with newlines |
| PASTE-04 | Items are draggable out of the popover into target apps via Transferable/NSItemProvider | `.draggable()` modifier with Transferable conformance; `FileRepresentation` + `ProxyRepresentation` for images; `DataRepresentation` or `CodableRepresentation` for text; `.simultaneousGesture` pattern to combine tap and drag |
</phase_requirements>

## Standard Stack

### Core

| Library / API | Version | Purpose | Why Standard |
|---------------|---------|---------|--------------|
| NSPasteboard | AppKit (macOS 10.0+) | Read/write system clipboard | Only way to write to macOS clipboard; `clearContents()` + `writeObjects` / `setString` / `setData` |
| Transferable protocol | SwiftUI (macOS 13+) | Declare drag-and-drop data representations | Modern Apple approach; `.draggable()` modifier requires it; String and URL already conform |
| UniformTypeIdentifiers | macOS 11+ | UTType constants for pasteboard types | Required for `FileRepresentation`, `ProxyRepresentation`; `.png`, `.image`, `.plainText`, `.fileURL` |

### Supporting

| API | Version | Purpose | When to Use |
|-----|---------|---------|-------------|
| NSItemProvider | Foundation | Lower-level drag data provider | Fallback if Transferable doesn't cover a case; used by `.onDrag` modifier |
| NSPasteboardWriting | AppKit | Protocol for pasteboard-writable objects | NSURL and NSString already conform; used with `writeObjects(_:)` for batch paste |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `.draggable()` + Transferable | `.onDrag { NSItemProvider(...) }` | onDrag is older API (macOS 11+); Transferable is cleaner and recommended for macOS 13+ which is our minimum target |
| NSPasteboard direct for single copy | SwiftUI `Clipboard` API | SwiftUI Clipboard is iOS-focused and limited; NSPasteboard gives full control needed for images |

## Architecture Patterns

### Recommended Project Structure

```
Copyhog/
├── Models/
│   └── ClipItem.swift            # Add Transferable conformance here
├── Services/
│   ├── ClipboardObserver.swift   # Existing — skipNextChange() already available
│   ├── PasteboardWriter.swift    # NEW — single and batch write helpers
│   └── ImageStore.swift          # Existing — resolveFullPath() needed
├── Store/
│   └── ClipItemStore.swift       # Existing — add copyToClipboard(item:) convenience
└── Views/
    ├── PopoverContent.swift      # Add multi-select state, toolbar button, batch copy button
    ├── ItemRow.swift             # Add tap-to-copy, checkbox, draggable
    └── PreviewPane.swift         # Unchanged
```

### Pattern 1: Single-Click Copy via NSPasteboard

**What:** Clicking an item row writes its content to the system clipboard.
**When to use:** PASTE-01
**Example:**

```swift
// PasteboardWriter.swift
import AppKit

struct PasteboardWriter {
    static func write(_ item: ClipItem, imageStore: ImageStore, clipboardObserver: ClipboardObserver) {
        let pasteboard = NSPasteboard.general

        // Tell our own observer to skip this change
        clipboardObserver.skipNextChange()

        pasteboard.clearContents()

        switch item.type {
        case .text:
            pasteboard.setString(item.content ?? "", forType: .string)
        case .image:
            if let filePath = item.filePath,
               let nsImage = imageStore.loadImage(relativePath: filePath),
               let tiffData = nsImage.tiffRepresentation {
                pasteboard.setData(tiffData, forType: .tiff)
            }
        }
    }
}
```

### Pattern 2: Multi-Select Batch Paste via writeObjects

**What:** Writes multiple image file URLs to pasteboard so receiving apps (Slack, Figma, Mail) get all selected images.
**When to use:** PASTE-03
**Example:**

```swift
static func writeMultiple(_ items: [ClipItem], imageStore: ImageStore, clipboardObserver: ClipboardObserver) {
    let pasteboard = NSPasteboard.general
    clipboardObserver.skipNextChange()
    pasteboard.clearContents()

    // Separate text and image items
    let textItems = items.filter { $0.type == .text }
    let imageItems = items.filter { $0.type == .image }

    var objects: [NSPasteboardWriting] = []

    // Concatenate text items with newlines
    if !textItems.isEmpty {
        let combined = textItems.compactMap(\.content).joined(separator: "\n")
        objects.append(combined as NSString)
    }

    // Add image file URLs
    for item in imageItems {
        if let filePath = item.filePath {
            let fullURL = imageStore.resolveURL(relativePath: filePath)
            objects.append(fullURL as NSURL)
        }
    }

    pasteboard.writeObjects(objects)
}
```

### Pattern 3: Transferable Conformance for Drag-Out

**What:** ClipItem conforms to Transferable so `.draggable()` works.
**When to use:** PASTE-04
**Example:**

```swift
// On ClipItem or a wrapper type
extension ClipItem: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        // Text items: plain text
        DataRepresentation(exportedContentType: .plainText) { item in
            guard item.type == .text, let content = item.content else {
                throw CocoaError(.fileNoSuchFile)
            }
            return Data(content.utf8)
        }

        // Image items: file on disk
        FileRepresentation(exportedContentType: .png) { item in
            guard item.type == .image, let filePath = item.filePath else {
                throw CocoaError(.fileNoSuchFile)
            }
            let url = ImageStore().resolveURL(relativePath: filePath)
            return SentTransferredFile(url)
        }

        // CRITICAL: ProxyRepresentation for Finder/Slack compatibility
        ProxyRepresentation { item in
            if item.type == .text {
                return item.content ?? ""
            } else if let filePath = item.filePath {
                return ImageStore().resolveURL(relativePath: filePath).absoluteString
            }
            return ""
        }
    }
}
```

### Pattern 4: Combining .draggable and .onTapGesture

**What:** Both click-to-copy and drag-out on the same row without gesture conflicts.
**When to use:** When PASTE-01 and PASTE-04 coexist on ItemRow.
**Example:**

```swift
// Place .draggable on inner content, .simultaneousGesture on outer HStack
HStack {
    // Inner content
    rowContent
        .draggable(item) {
            // Drag preview
            ItemRow(item: item, imageStore: imageStore, ...)
        }
}
.simultaneousGesture(TapGesture().onEnded {
    PasteboardWriter.write(item, imageStore: imageStore, clipboardObserver: observer)
})
```

Source: [Hacking with Swift Forums - .draggable and .onTapGesture](https://www.hackingwithswift.com/forums/swiftui/how-to-use-both-draggable-and-ontapgesture/26285)

### Anti-Patterns to Avoid

- **Calling `declareTypes(_:owner:)` before `writeObjects`:** This is the pre-10.6 API. Use `clearContents()` + `writeObjects` instead. Using both causes double-paste bugs.
- **Writing image data directly for batch paste:** Apps like Slack and Figma expect file URLs, not raw image data, when receiving multiple items. Use `NSURL` objects pointing to on-disk files.
- **Using `.onTapGesture` directly on a `.draggable` view:** The drag gesture swallows the tap. Put them on separate view hierarchy levels (inner vs outer).
- **Forgetting `skipNextChange()` before writing to pasteboard:** Without this, the ClipboardObserver re-captures our own write, creating a duplicate entry.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Writing to macOS clipboard | Custom pasteboard wrapper | `NSPasteboard.general` directly | Simple API, no abstraction needed beyond a thin helper |
| Drag data representation | Manual NSItemProvider setup | `Transferable` protocol + `.draggable()` | Apple's modern approach, handles UTType negotiation automatically |
| Multi-item pasteboard | Custom pasteboard item management | `writeObjects([NSURL])` | NSURL already conforms to NSPasteboardWriting; one line handles the whole array |
| Gesture conflict resolution | Custom gesture recognizer | `.simultaneousGesture` + view hierarchy separation | Documented SwiftUI pattern, works reliably |

**Key insight:** NSPasteboard and Transferable handle the hard parts (UTType negotiation, inter-app data transfer, lazy loading). The implementation is mostly wiring existing APIs together, not building custom infrastructure.

## Common Pitfalls

### Pitfall 1: ClipboardObserver Re-Capture Loop
**What goes wrong:** Writing to NSPasteboard.general to "copy" an item triggers the 0.5s ClipboardObserver poll, which re-captures the item as a new entry, creating duplicates.
**Why it happens:** The observer cannot distinguish between external clipboard changes and our own writes.
**How to avoid:** Call `clipboardObserver.skipNextChange()` before every `pasteboard.clearContents()` call. This flag is already implemented in the codebase.
**Warning signs:** Duplicate items appearing in the list immediately after clicking to copy.

### Pitfall 2: FileRepresentation-Only Drag Fails on macOS
**What goes wrong:** Dragging an image file from the app into Finder or Slack does nothing -- the drop is rejected silently.
**Why it happens:** On macOS 13-14, `FileRepresentation` alone is not sufficient for many receiving apps. This is a known Apple bug (FB13454434).
**How to avoid:** Always include a `ProxyRepresentation` returning the file URL alongside `FileRepresentation`. This dual-representation approach works across Finder, Slack, Figma, and other apps.
**Warning signs:** Drag cursor shows "not allowed" icon when hovering over drop targets.

Source: [Nonstrict - Transferable drag & drop fails with only FileRepresentation](https://nonstrict.eu/blog/2023/transferable-drag-drop-fails-with-only-FileRepresentation/)

### Pitfall 3: .draggable Swallows .onTapGesture
**What goes wrong:** Adding `.draggable()` to a view makes `.onTapGesture` on the same view stop firing.
**Why it happens:** The drag gesture recognizer takes priority and consumes the touch/click event before the tap gesture can process it.
**How to avoid:** Place `.draggable()` on an inner view and `.simultaneousGesture(TapGesture())` on an outer container view (e.g., the HStack wrapper).
**Warning signs:** Clicking a row does nothing (no clipboard write) but dragging still works.

Source: [Hacking with Swift Forums](https://www.hackingwithswift.com/forums/swiftui/how-to-use-both-draggable-and-ontapgesture/26285)

### Pitfall 4: MenuBarExtra Popover Cannot Be Dismissed Programmatically
**What goes wrong:** After copying, you may want to dismiss the popover so the user can immediately Cmd+V. With `MenuBarExtra(.window)` there is no public API to dismiss it.
**Why it happens:** Apple's MenuBarExtra with `.window` style does not expose open/close control (FB11984872).
**How to avoid:** Do NOT try to auto-dismiss. The user can click elsewhere or press Escape to dismiss. Attempting workarounds (like simulating a status item click) is fragile.
**Warning signs:** Attempting to call `NSApp.keyWindow?.close()` or similar hacks.

### Pitfall 5: Image File Path Resolution
**What goes wrong:** ClipItem stores relative paths for images. Passing a relative path to `NSURL` for pasteboard writing or `SentTransferredFile` for Transferable produces an invalid URL.
**Why it happens:** The relative path must be resolved against the App Support base directory to produce an absolute file URL.
**How to avoid:** Add a `resolveURL(relativePath:)` method to ImageStore that returns the full `URL`. Use this everywhere paths are resolved for pasteboard or drag operations.
**Warning signs:** Images fail to paste/drop in receiving apps; file-not-found errors in logs.

## Code Examples

### Single-Click Copy (Text)
```swift
// Source: Verified pattern from NSPasteboard documentation and Maccy clipboard manager
let pasteboard = NSPasteboard.general
clipboardObserver.skipNextChange()
pasteboard.clearContents()
pasteboard.setString("Hello world", forType: .string)
```

### Single-Click Copy (Image)
```swift
// Source: NSPasteboard documentation
let pasteboard = NSPasteboard.general
clipboardObserver.skipNextChange()
pasteboard.clearContents()
if let nsImage = imageStore.loadImage(relativePath: item.filePath!),
   let tiffData = nsImage.tiffRepresentation {
    pasteboard.setData(tiffData, forType: .tiff)
}
```

### Batch Paste (Multiple File URLs)
```swift
// Source: NSPasteboard.writeObjects documentation + Maccy clipboard manager pattern
let pasteboard = NSPasteboard.general
clipboardObserver.skipNextChange()
pasteboard.clearContents()

let urls: [NSURL] = imageItems.compactMap { item in
    guard let filePath = item.filePath else { return nil }
    return imageStore.resolveURL(relativePath: filePath) as NSURL
}
pasteboard.writeObjects(urls)
```

### Draggable Image Row
```swift
// Source: SwiftUI Transferable documentation + Nonstrict workaround
ItemRow(item: item, imageStore: imageStore, hoveredItemID: $hoveredItemID)
    .draggable(item) {
        // Lightweight drag preview
        Label(item.type == .text ? "Text" : "Image", systemImage: item.type == .text ? "doc.text" : "photo")
    }
```

### ImageStore URL Resolution
```swift
// Add to ImageStore.swift
func resolveURL(relativePath: String) -> URL {
    baseDirectory.appendingPathComponent(relativePath)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `.onDrag { NSItemProvider(...) }` | `.draggable(transferable)` | macOS 13 / WWDC 2022 | Cleaner API, automatic UTType negotiation |
| `declareTypes(_:owner:)` | `clearContents()` + `writeObjects()` | macOS 10.6 | Old API still works but is not recommended; causes bugs when mixed with writeObjects |
| Manual NSPasteboardItem creation | NSURL/NSString as NSPasteboardWriting | macOS 10.6+ | Built-in types already conform; no custom items needed for our use case |

**Deprecated/outdated:**
- `declareTypes(_:owner:)`: Pre-10.6 approach. Do not use with `writeObjects`.
- `NSFilenamesPboardType`: Deprecated in macOS 10.13. Use `NSPasteboard.PasteboardType.fileURL` or NSURL objects instead.

## Open Questions

1. **Tap-to-copy vs List selection behavior**
   - What we know: SwiftUI List has built-in selection behavior that can conflict with custom tap gestures on macOS. Using `.onTapGesture` inside List rows can break list scrolling or selection highlighting.
   - What's unclear: Whether the current ItemRow implementation (using List with plain style) will have gesture conflicts when adding both `.draggable` and tap handling.
   - Recommendation: Test with `.simultaneousGesture` on the outer HStack first. If conflicts arise, consider switching from List to ScrollView + LazyVStack (loses automatic list styling but gains full gesture control).

2. **Transferable conditional representation**
   - What we know: ClipItem has two types (text and image) but Transferable conformance declares all representations statically.
   - What's unclear: Whether a single Transferable conformance can cleanly handle both types, or if a wrapper enum/struct is cleaner.
   - Recommendation: Use a single conformance with guard clauses that throw for the wrong type. SwiftUI will try each representation in order and skip failures. Alternatively, create separate TextTransfer and ImageTransfer wrapper types.

3. **Batch paste behavior for mixed selections (text + images)**
   - What we know: The requirement says "writes selected image file URLs as NSPasteboardItem array to pasteboard." Text items are not explicitly addressed for batch paste.
   - What's unclear: Should mixed selections write text concatenated with newlines plus image URLs? Or only images?
   - Recommendation: Follow the shaping doc -- write image file URLs for images, concatenate text items with newlines. Both go to the same pasteboard via `writeObjects`.

## Sources

### Primary (HIGH confidence)
- NSPasteboard Apple documentation (developer.apple.com/documentation/appkit/nspasteboard) -- clearContents, writeObjects, setString, setData APIs
- [Nil Coalescing -- Copy String to Clipboard in Swift on macOS](https://nilcoalescing.com/blog/CopyStringToClipboardInSwiftOnMacOS/) -- verified clearContents + setString pattern
- [Maccy Clipboard Manager Source (Clipboard.swift)](https://github.com/p0deje/Maccy/blob/master/Maccy/Clipboard.swift) -- production clipboard manager patterns for write, skip-own-change, file URL handling

### Secondary (MEDIUM confidence)
- [Nonstrict -- Transferable drag & drop fails with only FileRepresentation](https://nonstrict.eu/blog/2023/transferable-drag-drop-fails-with-only-FileRepresentation/) -- ProxyRepresentation workaround, confirmed with Apple feedback FB13454434
- [Hacking with Swift Forums -- .draggable and .onTapGesture conflict](https://www.hackingwithswift.com/forums/swiftui/how-to-use-both-draggable-and-ontapgesture/26285) -- simultaneousGesture workaround
- [Swift with Majid -- Drag and Drop Transferable Data](https://swiftwithmajid.com/2023/04/05/drag-and-drop-transferable-data-in-swiftui/) -- .draggable modifier usage patterns
- [How to Actually Implement File Dragging from Your App on Mac](https://buckleyisms.com/blog/how-to-actually-implement-file-dragging-from-your-app-on-mac/) -- NSFilePromiseProvider for advanced cases (not needed for our use)

### Tertiary (LOW confidence)
- [Apple Developer Forums -- MenuBarExtra programmatic dismiss](https://github.com/feedback-assistant/reports/issues/383) -- confirms no public API for dismissing MenuBarExtra .window style

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- NSPasteboard and Transferable are well-documented Apple APIs with production examples
- Architecture: HIGH -- Patterns directly map to existing codebase structure; PasteboardWriter is a thin helper
- Pitfalls: HIGH -- Each pitfall is verified by official sources, community reports, or Apple feedback IDs

**Research date:** 2026-02-21
**Valid until:** 2026-03-21 (stable APIs, unlikely to change)
