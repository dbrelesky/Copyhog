# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-21)

**Core value:** Every screenshot and clipboard copy is captured and instantly accessible -- no hunting, no lost items, no broken workflow.
**Current focus:** Milestone v1.1 — Polish & Control

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-02-21 — Milestone v1.1 started

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 5
- Average duration: 19 min
- Total execution time: 1.5 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-capture-engine | 2/2 | 70 min | 35 min |
| 02-browse-ui | 1/1 | 15 min | 15 min |
| 03-paste-actions | 2/2 | 10 min | 5 min |

**Recent Trend:**
- Last 5 plans: 25 min, 45 min, 15 min, 2 min, 8 min
- Trend: improving

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Used SwiftUI MenuBarExtra (.window style) over NSStatusItem + NSPopover for simpler lifecycle management
- App Sandbox disabled in entitlements — required for NSEvent.addGlobalMonitorForEvents
- SMAppService.mainApp.register() used for launch-at-login (macOS 13+ API)
- Global hotkey (Shift+Up Arrow) registered but not functional — deferred to future plan; needs NSStatusItem-based toggle approach
- Timer-based NSPasteboard.changeCount polling at 0.5s — simpler and reliable vs NSPasteboardObserver private API
- DispatchSource O_EVTONLY directory watcher for screenshot detection — low-overhead kernel event approach
- isOwnWrite/skipNextChange flag pattern prevents infinite loop when ScreenshotWatcher copies screenshots to clipboard
- Relative paths in ClipItem for image storage — survive app relocation; resolved at runtime against App Support base
- Used @State hoveredItemID with onHover last-writer-wins pattern for macOS hover bug workaround
- PreviewPane height fixed at 200pt with aspect-fit images, scrollable text
- ContentUnavailableView for empty state — native macOS 14 component
- ClipboardObserver stored as optional var on ClipItemStore for view access — minimal change vs restructuring init chain
- Batch paste uses NSString and NSURL as NSPasteboardWriting objects for cross-app compatibility
- ProxyRepresentation throws for images to prevent exporting file path as text -- FileRepresentation handles images
- PasteboardWriter.writeMultiple rewritten to write all items in single writeObjects call

### Pending Todos

(Moved to v1.1 requirements — global hotkey fix)

### Blockers/Concerns

(None — hotkey fix is now an active requirement)

## Session Continuity

Last session: 2026-02-21
Stopped at: Milestone v1.1 initialization — defining requirements
Resume file: None
