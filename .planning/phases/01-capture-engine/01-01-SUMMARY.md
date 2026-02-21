---
phase: 01-capture-engine
plan: 01
subsystem: infra
tags: [swift, swiftui, macos, menubarextra, xcode, smappservice, nsstatusbarem]

# Dependency graph
requires: []
provides:
  - Xcode project (com.copyhog.app) targeting macOS 14.0
  - MenuBarExtra popover shell at 360x480px with hedgehog icon
  - Launch-at-login via SMAppService
  - App Sandbox disabled for global input monitoring
affects: [01-02, 01-03, 02-library, 03-search]

# Tech tracking
tech-stack:
  added: [SwiftUI MenuBarExtra, ServiceManagement (SMAppService), NSEvent global monitors, Xcode pbxproj]
  patterns: [MenuBarExtra with .window style for popover, LSUIElement for dock suppression, entitlements for sandbox override]

key-files:
  created:
    - Copyhog/Copyhog/CopyhogApp.swift
    - Copyhog/Copyhog/Views/PopoverContent.swift
    - Copyhog/Copyhog/Info.plist
    - Copyhog/Copyhog/Copyhog.entitlements
    - Copyhog/Copyhog/Assets.xcassets/MenuBarIcon.imageset/
    - Copyhog/Copyhog.xcodeproj/project.pbxproj
  modified: []

key-decisions:
  - "Used SwiftUI MenuBarExtra (.window style) over NSStatusItem + NSPopover for simpler lifecycle management"
  - "App Sandbox disabled in entitlements — required for NSEvent.addGlobalMonitorForEvents"
  - "LSUIElement = YES in Info.plist suppresses Dock icon without additional code"
  - "SMAppService.mainApp.register() used for launch-at-login (macOS 13+ API)"

patterns-established:
  - "App entry point: @main struct in CopyhogApp.swift using SwiftUI App protocol"
  - "MenuBarExtra content: PopoverContent.swift with explicit .frame(width: 360, height: 480)"
  - "Sandbox-off pattern: entitlements file with com.apple.security.app-sandbox = NO"

# Metrics
duration: ~25min
completed: 2026-02-21
---

# Phase 01 Plan 01: App Shell Summary

**macOS menu bar app shell using SwiftUI MenuBarExtra (.window style) with hedgehog icon, 360x480 popover, launch-at-login via SMAppService, and sandbox-disabled entitlements for global input monitoring**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-02-20T23:44:44Z
- **Completed:** 2026-02-21T05:05:30Z
- **Tasks:** 3 (2 auto + 1 checkpoint)
- **Files modified:** 6

## Accomplishments
- Built complete Xcode project from scratch (project.pbxproj, build settings, entitlements, asset catalog)
- Implemented MenuBarExtra popover with hedgehog icon and 360x480 PopoverContent placeholder
- Registered launch-at-login via SMAppService
- Verified: menu bar icon, popover open/dismiss, no Dock icon, login item registration all working

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Xcode project and configure app shell** - `a4b2d71` (feat)
2. **Task 2: Implement MenuBarExtra popover and launch-at-login** - `85a1e72` (feat)
3. **Task 3: Verify menu bar app shell works** - checkpoint approved by user

## Files Created/Modified
- `Copyhog/Copyhog/CopyhogApp.swift` - Main App struct: MenuBarExtra scene, SMAppService launch-at-login
- `Copyhog/Copyhog/Views/PopoverContent.swift` - Placeholder popover view at 360x480px
- `Copyhog/Copyhog/Info.plist` - LSUIElement = YES to suppress Dock icon, bundle ID, deployment target
- `Copyhog/Copyhog/Copyhog.entitlements` - App Sandbox disabled for NSEvent global monitor access
- `Copyhog/Copyhog/Assets.xcassets/MenuBarIcon.imageset/` - Hedgehog icon assets (16px and 32px template images)
- `Copyhog/Copyhog.xcodeproj/project.pbxproj` - Xcode project with macOS 14.0 target, Swift 6.0, entitlements, Info.plist wiring

## Decisions Made
- Used SwiftUI `MenuBarExtra` with `.menuBarExtraStyle(.window)` over the lower-level `NSStatusItem` + `NSPopover` approach — simpler lifecycle, fewer moving parts at this stage
- App Sandbox disabled via entitlements (not just capability flag) — required for `NSEvent.addGlobalMonitorForEvents`
- `SMAppService.mainApp.register()` called on init — macOS 13+ API, cleaner than legacy `LaunchServices` approach

## Deviations from Plan

None — plan executed as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness
- App shell is fully functional: icon, popover, no Dock icon, launch-at-login all verified
- PopoverContent.swift is the correct extension point for clipboard history UI (Plan 01-02 onwards)

## Self-Check: PASSED

All files and commits verified:
- FOUND: 01-01-SUMMARY.md
- FOUND: CopyhogApp.swift
- FOUND: PopoverContent.swift
- FOUND: Info.plist
- FOUND: Copyhog.entitlements
- FOUND: commit a4b2d71 (Task 1)
- FOUND: commit 85a1e72 (Task 2)

---
*Phase: 01-capture-engine*
*Completed: 2026-02-21*
