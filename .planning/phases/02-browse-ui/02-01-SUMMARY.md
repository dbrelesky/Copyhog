---
phase: 02-browse-ui
plan: 01
subsystem: ui
tags: [swiftui, popover, hover, preview-pane, clipboard-ui]

# Dependency graph
requires:
  - phase: 01-capture-engine
    provides: "ClipItem model, ClipItemStore, ImageStore with thumbnail/full-size loading"
provides:
  - "Split-view popover layout with PreviewPane + scrollable item list"
  - "Hover-driven preview showing full-size image or full text"
  - "Empty state with ContentUnavailableView"
  - "ItemRow component with 64x64 thumbnails and relative timestamps"
affects: [03-actions]

# Tech tracking
tech-stack:
  added: []
  patterns: ["hover-driven preview via @State hoveredItemID binding", "split-view popover layout (preview top, list bottom)"]

key-files:
  created:
    - "Copyhog/Copyhog/Views/PreviewPane.swift"
    - "Copyhog/Copyhog/Views/ItemRow.swift"
  modified:
    - "Copyhog/Copyhog/Views/PopoverContent.swift"
    - "Copyhog/Copyhog.xcodeproj/project.pbxproj"

key-decisions:
  - "Used @State hoveredItemID with onHover last-writer-wins pattern for macOS hover bug workaround"
  - "PreviewPane height fixed at 200pt with aspect-fit images, scrollable text"
  - "ContentUnavailableView for empty state — native macOS 14 component"

patterns-established:
  - "Hover-driven preview: @State hoveredItemID in parent, @Binding in child rows, computed previewItem falls back to most recent"
  - "Thumbnail vs full-size: ItemRow loads thumbnailPath (64x64), PreviewPane loads filePath (full-size)"

requirements-completed: []

# Metrics
duration: 15min
completed: 2026-02-21
---

# Phase 2 Plan 1: Browse UI Summary

**Split-view popover with hover-driven preview pane, 64x64 thumbnail item list, and ContentUnavailableView empty state**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-02-21
- **Completed:** 2026-02-21
- **Tasks:** 2 (1 auto + 1 human-verify)
- **Files modified:** 4

## Accomplishments
- Refactored monolithic PopoverContent into three focused SwiftUI views (PopoverContent, PreviewPane, ItemRow)
- Preview pane shows full-size image (aspect-fit) or scrollable full text for hovered item, defaults to most recent
- Item list rows display 64x64 thumbnails for images, text icon for text items, with 2-line snippets and relative timestamps
- Empty state uses native ContentUnavailableView with clipboard icon and helpful message
- Hover highlight on rows with subtle background color change

## Task Commits

Each task was committed atomically:

1. **Task 1: Refactor PopoverContent into split-view layout** - `2d7a7f2` (feat)
2. **Task 2: Verify browse UI in running app** - human-verify checkpoint (approved)

## Files Created/Modified
- `Copyhog/Copyhog/Views/PreviewPane.swift` - Full-size preview of hovered/selected clip item (image or text)
- `Copyhog/Copyhog/Views/ItemRow.swift` - Row component with 64x64 thumbnail, text snippet, relative timestamp, hover binding
- `Copyhog/Copyhog/Views/PopoverContent.swift` - Refactored to split-view layout with hoveredItemID state management
- `Copyhog/Copyhog.xcodeproj/project.pbxproj` - Added new view files to Xcode project

## Decisions Made
- Used @State hoveredItemID with onHover last-writer-wins pattern to handle known macOS hover exit-callback bug
- PreviewPane height fixed at 200pt — enough for meaningful preview without crowding the item list
- ContentUnavailableView chosen for empty state as the native macOS 14+ component

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Browse UI complete with preview and hover interaction
- Ready for Phase 3 (actions): copy-to-clipboard, delete, pin, and search functionality can build on this item list and preview infrastructure

## Self-Check: PASSED

All files verified present. Commit 2d7a7f2 verified in git log.

---
*Phase: 02-browse-ui*
*Completed: 2026-02-21*
