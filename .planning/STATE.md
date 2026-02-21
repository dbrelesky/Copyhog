# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-20)

**Core value:** Every screenshot and clipboard copy is captured and instantly accessible -- no hunting, no lost items, no broken workflow.
**Current focus:** Phase 3: Paste Actions

## Current Position

Phase: 3 of 3 (Paste Actions)
Plan: 1 of 2 in current phase
Status: In progress
Last activity: 2026-02-21 -- Completed 03-01 paste actions plan

Progress: [████████░░] 80%

## Performance Metrics

**Velocity:**
- Total plans completed: 4
- Average duration: 22 min
- Total execution time: 1.4 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-capture-engine | 2/2 | 70 min | 35 min |
| 02-browse-ui | 1/1 | 15 min | 15 min |
| 03-paste-actions | 1/2 | 2 min | 2 min |

**Recent Trend:**
- Last 5 plans: 25 min, 45 min, 15 min, 2 min
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

### Pending Todos

- Fix global hotkey toggle: MenuBarExtra doesn't expose programmatic open/close; next plan should use NSStatusItem button action or NSPanel ordering

### Blockers/Concerns

- Known issue: Shift+Up Arrow global hotkey does not toggle the popover at runtime. Approved and deferred. Will need a different toggle mechanism (NSStatusItem direct control or NSPanel).

## Session Continuity

Last session: 2026-02-21
Stopped at: Completed 03-01-PLAN.md (paste actions)
Resume file: None
