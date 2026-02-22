# Project Research Summary

**Project:** Copyhog v1.2 Power User Features
**Domain:** macOS menu bar clipboard manager — power user upgrade
**Researched:** 2026-02-21
**Confidence:** MEDIUM-HIGH

## Executive Summary

Copyhog v1.2 is a focused feature upgrade to an existing Swift + SwiftUI macOS menu bar app. The goal is to transform it from a casual clipboard helper into a keyboard-driven power tool that competes with Maccy, Paste, and CleanClip. Research confirms this is achievable without any architectural rewrites — the existing MenuBarExtra + ClipItemStore foundation is sound. Only two external Swift packages are needed: `soffes/HotKey` for the global keyboard shortcut and `orchetect/MenuBarExtraAccess` to programmatically toggle the popover (a gap Apple has not filled in first-party APIs). All other features — search, keyboard navigation, pinned items, screenshot auto-detection — use built-in Apple frameworks.

The recommended implementation order is driven by dependency chains: data model changes must come before UI features that depend on them, and search must be in place before keyboard navigation can work correctly. The single most important decision the research uncovered is to NOT raise the history limit before addressing persistence performance. The current pattern (full-array JSON encode on every clipboard change) will cause write contention and UI stutter at 500+ items. Debouncing saves is the minimum fix; SQLite via GRDB is the correct long-term solution if JSON proves insufficient at scale.

The primary risks are two third-party workarounds (MenuBarExtraAccess uses private API introspection for popover control, and the Paste-on-Select feature requires Accessibility permission via CGEvent simulation). Both are well-established community patterns with known recovery strategies. Copyhog's unique competitive angle — zero-config screenshot integration — is genuinely absent from all competitors and should be preserved and strengthened by the auto-detect screenshot location feature.

## Key Findings

### Recommended Stack

The existing Swift + SwiftUI stack requires only two SPM package additions. `orchetect/MenuBarExtraAccess` (1.2.x) solves the fundamental problem of programmatic MenuBarExtra toggle — Apple has confirmed (FB10185203, FB11984872) they will not fix this gap in first-party APIs. `soffes/HotKey` (v0.2.1+) provides global hotkey registration via Carbon APIs with a clean Swift wrapper. Copyhog already uses `.menuBarExtraStyle(.window)`, which is the prerequisite for MenuBarExtraAccess to function.

No persistence migration is needed initially. At 500 items of metadata (text strings + image file paths), JSON encodes to well under 1MB — but the save pattern must be debounced. The STACK.md research explicitly recommends against SwiftData or Core Data at this scale: the complexity cost vastly exceeds the performance benefit. GRDB.swift is the contingency path if debounced JSON proves insufficient, but profiling should drive that decision.

**Core technologies:**
- `soffes/HotKey`: global Cmd+Shift+V registration — cleanest Carbon API wrapper, no user-customizable recorder UI (not needed for a hard-coded default)
- `orchetect/MenuBarExtraAccess`: programmatic popover toggle — only viable solution for this gap, Mac App Store safe
- SwiftUI `.searchable()` / custom TextField: search bar — zero dependencies, built-in macOS 13+ behavior
- `NSEvent.addLocalMonitorForEvents`: keyboard navigation — more reliable than `@FocusState` inside MenuBarExtra's NSPanel
- `UserDefaults(suiteName: "com.apple.screencapture")`: screenshot location detection — stable system preference key, no dependencies
- `NSCache<NSString, NSImage>`: thumbnail caching — prevents scroll stutter at 500+ items, must be added alongside history limit increase

### Expected Features

Research identified four table-stakes features that competitors universally provide, and three differentiators worth shipping in v1.2. The dependency structure is clear: global hotkey unlocks keyboard-driven workflows, large history makes search essential, and pinned items only matter when items get purged.

**Must have (table stakes):**
- Global hotkey (Cmd+Shift+V) — transforms Copyhog from "menu bar toy" to "essential daily tool"; every competitor has this
- Search/filter — required companion to large history; 500 items without search is unusable
- Keyboard navigation (arrow keys + Enter) — natural extension of hotkey workflow; deal-breaker for power users if missing
- Large history (500 items) — raise maxItems cap; JSON metadata at this scale is fine with debounced saves

**Should have (competitive differentiators):**
- Paste-on-select — Enter pastes directly into previous app via CGEvent; requires Accessibility permission; highest value add but adds permission complexity
- Pinned items — `isPinned: Bool` on ClipItem; survives history purge; medium effort, high retention value
- Auto-detect screenshot location — reads `com.apple.screencapture` defaults; eliminates onboarding friction; unique to Copyhog among competitors

**Defer (v1.3+):**
- Customizable hotkey — nice-to-have via KeyboardShortcuts `Recorder` view; ship when users request it
- Snippet/template system — out of scope; TextExpander territory
- iCloud sync — massive complexity, not justified at this stage
- Regex/fuzzy search — overkill; case-insensitive substring covers 95% of use cases

### Architecture Approach

The existing architecture requires targeted modifications, not a rewrite. The core pattern is: add `isPinned` to ClipItem (with Codable migration via `decodeIfPresent`), compute a single `displayItems` property on ClipItemStore that handles pin sorting then search filtering, install an NSEvent local monitor in PopoverContent for keyboard events (bypassing unreliable `@FocusState` in MenuBarExtra's NSPanel), and bridge the `isPresented` binding between the SwiftUI App struct and AppDelegate's HotKey callback via a `@Published` property on AppDelegate.

**Major components (new or modified):**
1. `MenuBarExtraAccess` binding in CopyhogApp — exposes `isPresented` toggle for hotkey and programmatic control
2. `HotKey` instance in AppDelegate — registers Cmd+Shift+V, fires toggle on keydown
3. `ClipItemStore.displayItems` computed property — pin-sorted + search-filtered, single source of truth for the view
4. `NSEvent` local monitor in PopoverContent — handles arrow keys, Enter, Escape; manages lifecycle in onAppear/onDisappear
5. `ScreenshotLocationDetector` utility — reads `com.apple.screencapture` defaults, falls back to ~/Desktop
6. `NSCache` thumbnail layer in ImageStore — prevents memory bloat and scroll stutter at 500+ items

### Critical Pitfalls

1. **MenuBarExtra has no programmatic show/hide API** — using `NSStatusItem.button?.performClick(nil)` as a hack breaks across macOS versions; use `MenuBarExtraAccess` exclusively. Must be solved first — every keyboard-driven feature depends on being able to open the popover from a hotkey.

2. **Full-array JSON encode on every clipboard change** — at 500+ items this causes write contention and UI stutter; debounce saves to 1 second, trigger immediate save on `applicationWillTerminate`. Do NOT raise the history limit before addressing this.

3. **LazyVGrid does not recycle views** — once rendered, items stay in memory; at 500+ items with thumbnails this causes scroll lag and memory bloat; add `NSCache<NSString, NSImage>` thumbnail cache in ImageStore; consider `List` with HStack rows for proper view recycling.

4. **Global hotkey conflicts with other apps** — Carbon's `RegisterEventHotKey` is first-come-first-served with no conflict detection; use `sindresorhus/KeyboardShortcuts` if user-customizable shortcut is needed, or ship a settings recorder within 2 weeks of launch.

5. **Keyboard navigation swallowed by ScrollView or TextField** — arrow keys are consumed by both; use `NSEvent.addLocalMonitorForEvents` and explicit focus state tracking (`@State var isSearchFieldFocused`) to route events correctly: search field focused = arrow keys go to text field; list focused = arrow keys move selection.

6. **Sandbox access to `com.apple.screencapture` defaults** — in a fully sandboxed app, `UserDefaults(suiteName:)` for another app's domain returns nil; use `Process` to run `defaults read com.apple.screencapture location` or read the plist directly; verify Copyhog's actual entitlements before choosing the implementation path.

## Implications for Roadmap

Based on research, the dependency chain is clear and non-negotiable: data model before UI, persistence before scale, search before keyboard nav, everything before global hotkey integration. Four phases map directly to these dependencies.

### Phase 1: Auto-Detect Screenshot Location

**Rationale:** Fully independent — no dependencies on any other v1.2 feature. Low risk, isolated change. Ships user-visible value immediately and strengthens Copyhog's unique differentiator (screenshot integration). A good warm-up phase before touching shared infrastructure.

**Delivers:** Zero-config screenshot source detection; pre-fills NSOpenPanel to detected directory; reduces onboarding friction from 2 folder picks to 1.

**Implements:** `ScreenshotLocationDetector` utility; modifications to ScreenshotWatcher, BookmarkManager, OnboardingView.

**Avoids:** Sandbox access pitfall (verify entitlements and choose correct read path before writing code).

**Research flag:** LOW — pattern is well-documented; only sandbox behavior needs runtime verification.

### Phase 2: Data Model + Persistence Hardening (Pinned Items + 500-Item History)

**Rationale:** Must precede search and keyboard navigation because `displayItems` (the computed property that both features consume) requires the pin-sorted data model. Must precede raising the history limit to avoid write contention at scale. This is the foundational phase — every subsequent feature builds on it.

**Delivers:** `isPinned: Bool` on ClipItem with Codable migration; debounced saves; purge logic that skips pinned items; `displayItems` computed property combining pin sort + search filter; maxItems cap raised to 500; `NSCache` thumbnail layer in ImageStore.

**Implements:** ClipItem model change, ClipItemStore purge/sort logic, ImageStore cache, debounced save pattern.

**Avoids:** Full-array JSON encode pitfall; LazyVGrid memory bloat pitfall; storing pins separately (two-source-of-truth anti-pattern).

**Research flag:** LOW — all patterns are standard Swift/Codable; debounced Task pattern is straightforward.

### Phase 3: Search + Keyboard Navigation

**Rationale:** Search depends on Phase 2's `displayItems` pattern being in place. Keyboard navigation depends on search being implemented because the critical interaction is: hotkey opens popover, search field auto-focuses, user types to filter, arrow keys shift to grid navigation. These two features must be built and tested together — building keyboard nav without search leads to incorrect focus management.

**Delivers:** Search bar at top of PopoverContent; case-insensitive substring filter on text items; auto-focus on popover open; arrow key navigation through grid; Enter to copy selected item; Escape to clear search or dismiss; visible selection highlight on keyboard-focused item; empty state for no search results.

**Implements:** SearchBar in PopoverContent; NSEvent local monitor; selectedIndex state; focus routing logic between search field and grid.

**Avoids:** Keyboard nav swallowed by ScrollView pitfall; @FocusState unreliability in MenuBarExtra NSPanel; search filtering on every keystroke (debounce 300ms).

**Research flag:** MEDIUM — NSEvent local monitor interaction with SwiftUI focus system in MenuBarExtra NSPanel requires careful runtime testing; the focus routing logic (search field vs grid) is the hardest part.

### Phase 4: Global Hotkey + Paste-on-Select

**Rationale:** This is the capstone phase. It has the most integration points (CopyhogApp, AppDelegate, PopoverContent) and depends on everything in Phases 1-3 being stable. The hotkey must open a popover that already has search, keyboard nav, and pinned items working correctly. Paste-on-Select (CGEvent Cmd+V simulation) is bundled here because it completes the keyboard-driven flow: hotkey to open, type to search, arrow to select, Enter to paste-and-dismiss.

**Delivers:** Global Cmd+Shift+V hotkey toggles popover from any app; popover auto-focuses search field on hotkey open; Enter pastes selected item into previous app (with Accessibility permission); fallback to copy-only without permission; Accessibility permission prompt on first use.

**Implements:** `soffes/HotKey` package; `orchetect/MenuBarExtraAccess` binding; `@Published var isMenuPresented` on AppDelegate; CGEvent Cmd+V simulation; previous-app tracking via NSWorkspace.

**Avoids:** MenuBarExtra no-programmatic-toggle pitfall; hotkey conflict pitfall; self-write loop in ClipboardObserver (verify existing flag handles this).

**Research flag:** HIGH — MenuBarExtraAccess uses private API introspection and is a community workaround; hotkey-to-popover binding bridge between App struct and AppDelegate requires careful testing; CGEvent paste simulation requires Accessibility permission with graceful degradation; test on multiple machines with different apps installed.

### Phase Ordering Rationale

- Auto-detect screenshot is truly independent — doing it first ships value and builds confidence before touching shared infrastructure.
- Data model changes propagate everywhere — `isPinned`, `displayItems`, and debounced saves affect every subsequent feature; doing them first means later phases build on a stable foundation.
- Search and keyboard navigation share focus state management — they are logically one feature split across view and model; building them in the same phase ensures the focus routing is designed correctly from the start.
- Global hotkey is the highest-complexity integration, touching the App struct, AppDelegate, and PopoverContent simultaneously — it belongs last when all the pieces it orchestrates are stable.

### Research Flags

Phases likely needing deeper research or careful runtime testing:

- **Phase 3 (Search + Keyboard Navigation):** NSEvent local monitor behavior inside MenuBarExtra's NSPanel is sparsely documented; the focus routing between TextField and LazyVGrid needs iterative testing; verify that `onDisappear` cleanup of the monitor prevents double-installs on repeated open/close.
- **Phase 4 (Global Hotkey + Paste-on-Select):** MenuBarExtraAccess uses private API introspection — test on macOS 13, 14, and 15 before shipping; CGEvent paste simulation timing (dismiss popover, wait ~100ms, simulate Cmd+V) needs runtime calibration; verify ClipboardObserver self-write flag handles the hotkey-triggered paste path.

Phases with well-established patterns (research-phase can be skipped):

- **Phase 1 (Auto-Detect Screenshot Location):** Pattern is documented and stable; only entitlement verification needed before coding.
- **Phase 2 (Data Model + Persistence):** Codable `decodeIfPresent` migration, debounced Task save, and NSCache are all standard Swift patterns with no surprises.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Two SPM packages are well-documented with production usage verified; built-in APIs for search, keyboard nav, and screenshot detection are stable macOS 13+ features |
| Features | HIGH | Feature landscape well-understood; competitor analysis confirmed; dependency chain clearly documented |
| Architecture | MEDIUM-HIGH | Core patterns are solid; MenuBarExtraAccess private API introspection is the one variable; NSEvent local monitor in MenuBarExtra NSPanel needs runtime verification |
| Pitfalls | MEDIUM-HIGH | Most pitfalls verified against Maccy source and Apple Developer Forums; sandbox behavior for `com.apple.screencapture` defaults needs runtime confirmation in Copyhog's specific entitlements |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Sandbox entitlements for `com.apple.screencapture` defaults:** Copyhog uses security-scoped bookmarks, suggesting it is not fully sandboxed — but the exact entitlements need to be checked before choosing between `UserDefaults(suiteName:)` direct read vs `Process`-based `defaults read` command. Verify in Phase 1.
- **MenuBarExtraAccess macOS 26 compatibility:** The package uses runtime introspection of NSStatusItem internals. As of research date, it is confirmed working on macOS 13/14/15 — but macOS 26 (current beta) compatibility has not been verified. Pin to a tested version and monitor the package repo.
- **CGEvent paste timing:** The 100ms delay between popover dismiss and Cmd+V simulation (for Paste-on-Select) is a community-established heuristic. Some apps (particularly Electron-based) may need different timing. Needs calibration during Phase 4.
- **GRDB migration path:** JSON with debounced saves is the starting recommendation for 500 items. The threshold at which GRDB becomes necessary was not benchmarked against Copyhog's specific ClipItem structure. If saves exceed 50ms at 500 items in profiling, GRDB migration should be planned as a fast-follow.

## Sources

### Primary (HIGH confidence)
- [orchetect/MenuBarExtraAccess](https://github.com/orchetect/MenuBarExtraAccess) — programmatic MenuBarExtra toggle; confirmed no first-party alternative
- [soffes/HotKey](https://github.com/soffes/HotKey) — global hotkey via Carbon APIs; stable, widely used
- [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — user-customizable shortcuts alternative; Mac App Store verified
- [Apple FB10185203 + FB11984872](https://github.com/feedback-assistant/reports) — confirms MenuBarExtra programmatic toggle is a known missing API
- [Maccy source code](https://github.com/p0deje/Maccy) — reference implementation for CGEvent paste, keyboard navigation, storage patterns
- [WWDC23 SwiftUI Cookbook for Focus](https://developer.apple.com/videos/play/wwdc2023/10162/) — `@FocusState`, `focusable()`, `onMoveCommand` patterns
- [macos-defaults.com: screenshot location](https://macos-defaults.com/screenshots/location.html) — `com.apple.screencapture location` key documentation

### Secondary (MEDIUM confidence)
- [groue/GRDB.swift](https://github.com/groue/GRDB.swift) — SQLite toolkit; fallback persistence path if JSON proves slow
- [Paste app](https://pasteapp.io/) and [CleanClip](https://cleanclip.cc/) — competitor feature reference
- [Apple Developer Forums: SwiftUI List performance on macOS](https://developer.apple.com/forums/thread/650238) — List recycling vs LazyVGrid memory retention
- [Maccy Issue #1097](https://github.com/p0deje/Maccy/issues/1097) — rendering bottleneck at scale confirmed by maintainer
- [SwiftUI List vs LazyVStack benchmarks](https://fatbobman.com/en/posts/list-or-lazyvstack/) — view recycling behavior

### Tertiary (LOW confidence — needs validation)
- macOS 26 Spotlight clipboard manager ([9to5Mac](https://9to5mac.com/2025/06/10/macos-26-spotlight-gets-actions-clipboard-manager-custom-shortcuts/)) — potential future competitive threat; functionality not yet confirmed
- CGEvent paste timing (100ms heuristic) — community consensus, not Apple-documented; needs runtime validation

---
*Research completed: 2026-02-21*
*Ready for roadmap: yes*
