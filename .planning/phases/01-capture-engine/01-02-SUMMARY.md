---
phase: 01-capture-engine
plan: 02
subsystem: capture
tags: [swift, swiftui, macos, nspasteboard, dispatchsource, filemanager, imagestore, persistence]

# Dependency graph
requires:
  - phase: 01-01
    provides: Xcode project shell, CopyhogApp.swift entry point, PopoverContent.swift view, sandbox-disabled entitlements
provides:
  - ClipItem Codable model (id, type, content, thumbnailPath, filePath, timestamp)
  - ImageStore service (save/load/delete images in ~/Library/Application Support/Copyhog/)
  - ClipItemStore ObservableObject with 20-item cap, JSON persistence, auto-purge with image cleanup
  - ClipboardObserver timer-based NSPasteboard.changeCount polling at 0.5s for text and images
  - ScreenshotWatcher DispatchSource directory monitor, moves screenshots to ~/Documents/Screenies/, copies to clipboard
  - Infinite-loop prevention via isOwnWrite/skipNextChange pattern
  - PopoverContent showing captured items with 120x120 image thumbnails loaded from ImageStore
affects: [01-03, 02-library, 03-search]

# Tech tracking
tech-stack:
  added: [NSPasteboard, DispatchSource, DispatchSourceFileSystemObject, FileManager, NSBitmapImageRep, JSONEncoder/JSONDecoder, Timer]
  patterns: [changeCount polling for clipboard detection, DispatchSource O_EVTONLY directory monitoring, isOwnWrite flag for clipboard loop prevention, relative paths for App Support storage, async file stability check before processing]

key-files:
  created:
    - Copyhog/Copyhog/Models/ClipItem.swift
    - Copyhog/Copyhog/Services/ImageStore.swift
    - Copyhog/Copyhog/Store/ClipItemStore.swift
    - Copyhog/Copyhog/Services/ClipboardObserver.swift
    - Copyhog/Copyhog/Services/ScreenshotWatcher.swift
  modified:
    - Copyhog/Copyhog/CopyhogApp.swift
    - Copyhog/Copyhog/Views/PopoverContent.swift

key-decisions:
  - "Timer-based NSPasteboard.changeCount polling at 0.5s — simpler and reliable vs NSPasteboardObserver private API"
  - "DispatchSource O_EVTONLY directory watcher for screenshot detection — low-overhead kernel event approach"
  - "isOwnWrite/skipNextChange flag pattern to prevent infinite loop when ScreenshotWatcher copies to clipboard"
  - "Relative paths in ClipItem for thumbnailPath and filePath — survive app relocation; resolved at runtime against App Support base"
  - "Image thumbnails at 120x120 in PopoverContent (fixed during verification from initial 40x40 generic icons) — loads actual NSImage from ImageStore"

patterns-established:
  - "Clipboard loop prevention: call skipNextChange() BEFORE writing to NSPasteboard, not after"
  - "Screenshot stability: read file size, wait 0.2s, read again — retry if changed"
  - "Service lifetime: ClipboardObserver and ScreenshotWatcher held as strong properties on App struct, started in init(), not in view onAppear"
  - "Image storage: full image as {id}.png, thumbnail as {id}_thumb.png in ~/Library/Application Support/Copyhog/"

# Metrics
duration: ~45min
completed: 2026-02-21
---

# Phase 01 Plan 02: Capture Engine Summary

**NSPasteboard changeCount polling + DispatchSource directory watching capturing clipboard text, clipboard images, and screenshots into a 20-item JSON-persisted store with infinite-loop prevention**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-02-21
- **Completed:** 2026-02-21
- **Tasks:** 3 (2 auto + 1 checkpoint:human-verify)
- **Files modified:** 7

## Accomplishments

- Built complete capture pipeline: text and image clipboard events captured within 0.5s of system copy
- Screenshot watcher detects new PNG files via DispatchSource, moves them to ~/Documents/Screenies/, copies to clipboard, and creates a ClipItem — all without creating duplicate entries
- ClipItemStore persists up to 20 items as JSON in App Support, auto-purges oldest with image file cleanup on overflow
- PopoverContent updated to display captured items with real 120x120 thumbnail images loaded from ImageStore

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ClipItem model, ImageStore, and ClipItemStore with persistence** - `dac844b` (feat)
2. **Task 2: Implement ClipboardObserver, ScreenshotWatcher, and wire into app** - `e8d6b14` (feat)
3. **Task 3: Verify capture engine end-to-end** - checkpoint approved by user

## Files Created/Modified

- `Copyhog/Copyhog/Models/ClipItem.swift` - Codable struct with id (UUID), type (.text/.image), content, thumbnailPath, filePath, timestamp; relative path storage
- `Copyhog/Copyhog/Services/ImageStore.swift` - Save/load/delete images in ~/Library/Application Support/Copyhog/; generates 64x64 thumbnails via NSBitmapImageRep
- `Copyhog/Copyhog/Store/ClipItemStore.swift` - ObservableObject with @Published items, 20-item cap, JSON persistence with .iso8601 encoding, auto-purge with ImageStore cleanup
- `Copyhog/Copyhog/Services/ClipboardObserver.swift` - Timer at 0.5s polling NSPasteboard.changeCount; captures .string and .tiff/.png; isOwnWrite flag prevents infinite loop
- `Copyhog/Copyhog/Services/ScreenshotWatcher.swift` - DispatchSource O_EVTONLY dir monitor; detects new "Screenshot*" PNGs, moves to Screenies/, copies to clipboard with skipNextChange(); file stability check via size comparison
- `Copyhog/Copyhog/CopyhogApp.swift` - Wires ClipboardObserver and ScreenshotWatcher as app-lifetime properties, starts both in init()
- `Copyhog/Copyhog/Views/PopoverContent.swift` - Displays ClipItem list; image items show 120x120 NSImage thumbnail loaded from ImageStore

## Decisions Made

- **changeCount polling over delegate/notification API:** NSPasteboard has no public observer mechanism. Timer polling at 0.5s is the canonical macOS approach and reliable across app types.
- **DispatchSource over FSEvents for screenshot dir:** Lower overhead for a single directory; O_EVTONLY prevents the watcher from blocking unmount. FSEvents would be overkill here.
- **skipNextChange() called before pasteboard write:** The flag must be set before the write happens so the 0.5s timer fires after the write and sees isOwnWrite=true. Calling it after would miss the event window.
- **Relative image paths in ClipItem:** Absolute paths break if user moves the app. Paths like `{id}.png` are resolved at runtime against the App Support directory.
- **Thumbnail size bumped to 120x120 during verification:** Initial 40x40 was too small and showed generic system icons; 120x120 with actual NSImage data provides useful visual preview.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Image thumbnails displayed as generic icons instead of actual image content**
- **Found during:** Task 3 (human verification checkpoint)
- **Issue:** PopoverContent was rendering image items at 40x40 with a generic icon placeholder rather than loading the actual thumbnail from ImageStore. The thumbnail path was stored correctly in ClipItem but not used to load the NSImage for display.
- **Fix:** Updated PopoverContent to call `imageStore.loadImage(relativePath: item.thumbnailPath)` and display the resulting NSImage at 120x120. Size increased from 40x40 to 120x120 for usable visual preview.
- **Files modified:** Copyhog/Copyhog/Views/PopoverContent.swift
- **Verification:** User confirmed thumbnails load and display correctly during the verification checkpoint.
- **Committed in:** e8d6b14 (Task 2 commit, applied during verification)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug)
**Impact on plan:** Fix was necessary for the popover to show meaningful content. No scope creep.

## Issues Encountered

None beyond the thumbnail display bug documented above, which was caught and fixed during human verification.

## User Setup Required

None — no external service configuration required. All storage is local (~/Library/Application Support/Copyhog/ and ~/Documents/Screenies/).

## Next Phase Readiness

- Full capture engine is operational: text, images, and screenshots all captured automatically
- Items persist across restarts and display in the popover with thumbnails
- PopoverContent is wired to ClipItemStore as @EnvironmentObject — ready for Plan 01-03 UI polish (search, keyboard navigation, clip detail view)
- Known deferred item from 01-01 still pending: global hotkey toggle mechanism needs NSStatusItem-based approach

## Self-Check

- FOUND: 01-02-SUMMARY.md at .planning/phases/01-capture-engine/01-02-SUMMARY.md
- FOUND: Copyhog/Copyhog/Models/ClipItem.swift
- FOUND: Copyhog/Copyhog/Services/ImageStore.swift
- FOUND: Copyhog/Copyhog/Store/ClipItemStore.swift
- FOUND: Copyhog/Copyhog/Services/ClipboardObserver.swift
- FOUND: Copyhog/Copyhog/Services/ScreenshotWatcher.swift
- FOUND: commit dac844b (Task 1)
- FOUND: commit e8d6b14 (Task 2)

## Self-Check: PASSED

---
*Phase: 01-capture-engine*
*Completed: 2026-02-21*
