# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-20)

**Core value:** Every screenshot and clipboard copy is captured and instantly accessible -- no hunting, no lost items, no broken workflow.
**Current focus:** Phase 2: Browse UI

## Current Position

Phase: 2 of 3 (Browse UI)
Plan: 1 of 1 in current phase (phase complete)
Status: In progress
Last activity: 2026-02-21 -- Completed 02-01 browse UI

Progress: [████░░░░░░] 40%

## Performance Metrics

**Velocity:**
- Total plans completed: 3
- Average duration: 28 min
- Total execution time: 1.4 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-capture-engine | 2/2 | 70 min | 35 min |
| 02-browse-ui | 1/1 | 15 min | 15 min |

**Recent Trend:**
- Last 5 plans: 25 min, 45 min, 15 min
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

### Pending Todos

- Fix global hotkey toggle: MenuBarExtra doesn't expose programmatic open/close; next plan should use NSStatusItem button action or NSPanel ordering

### Blockers/Concerns

- Known issue: Shift+Up Arrow global hotkey does not toggle the popover at runtime. Approved and deferred. Will need a different toggle mechanism (NSStatusItem direct control or NSPanel).

## Session Continuity

Last session: 2026-02-21
Stopped at: Completed 02-01-PLAN.md — browse UI verified (split-view popover with hover preview)
Resume file: None
