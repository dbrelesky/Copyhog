# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-20)

**Core value:** Every screenshot and clipboard copy is captured and instantly accessible -- no hunting, no lost items, no broken workflow.
**Current focus:** Phase 1: Capture Engine

## Current Position

Phase: 1 of 3 (Capture Engine)
Plan: 2 of 2 in current phase (phase complete)
Status: In progress
Last activity: 2026-02-21 -- Completed 01-02 capture engine

Progress: [██░░░░░░░░] 20%

## Performance Metrics

**Velocity:**
- Total plans completed: 2
- Average duration: 35 min
- Total execution time: 1.2 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-capture-engine | 2/2 | 70 min | 35 min |

**Recent Trend:**
- Last 5 plans: 25 min, 45 min
- Trend: +

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

### Pending Todos

- Fix global hotkey toggle: MenuBarExtra doesn't expose programmatic open/close; next plan should use NSStatusItem button action or NSPanel ordering

### Blockers/Concerns

- Known issue: Shift+Up Arrow global hotkey does not toggle the popover at runtime. Approved and deferred. Will need a different toggle mechanism (NSStatusItem direct control or NSPanel).

## Session Continuity

Last session: 2026-02-21
Stopped at: Completed 01-02-PLAN.md — capture engine verified (text, images, screenshots all captured)
Resume file: None
