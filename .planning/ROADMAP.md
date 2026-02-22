# Roadmap: Copyhog

## Milestones

- v1.0 MVP - Phases 1-3 (shipped 2026-02-21)
- v1.1 Polish & Control - Phases 4-5 + 04.1-04.3 (shipped 2026-02-22)
- v1.2 Power User Essentials - Phases 6-9 (in progress)

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

<details>
<summary>v1.0 MVP (Phases 1-3) - SHIPPED 2026-02-21</summary>

- [x] **Phase 1: Capture Engine** - Menu bar shell, clipboard observer, screenshot watcher, and persistent item store
- [x] **Phase 2: Browse UI** - Split-view popover with preview pane, item list, and hover interaction
- [x] **Phase 3: Paste Actions** - Single-click copy, multi-select batch paste, and drag-out

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

<details>
<summary>v1.1 Polish & Control (Phases 4-5 + 04.1-04.3) - SHIPPED 2026-02-22</summary>

- [x] **Phase 4: User Control** - Swipe-to-delete and Hog Wipe with confirmation (1/1 plan)
- [x] **Phase 04.1: Settings Menu** (INSERTED) - Gear icon dropdown with version, attribution, relocated actions (2/2 plans)
- [x] **Phase 04.2: Liquid Glass UI** (INSERTED) - Translucent materials, elevated preview, floating toolbar (1/1 plan)
- [x] **Phase 04.3: App Store Readiness** (INSERTED) - Sandbox, privacy strings, exclusion list (shipped direct)
- [x] **Phase 5: Privacy & Compliance** - Privacy manifest, launch toggle, configurable history (1/1 plan)

Full details: `.planning/milestones/v1.1-ROADMAP.md`

</details>

## v1.2 Power User Essentials

**Milestone Goal:** Make Copyhog a keyboard-driven power tool -- instant access from anywhere, searchable history, pinned favorites, and zero-config screenshot detection.

- [x] **Phase 6: Screenshot Auto-Detection** - Auto-detect macOS screenshot save location (completed 2026-02-22)
- [x] **Phase 7: Favorites + History Scale** - Pinned items, 500-item history, debounced persistence (completed 2026-02-22)
- [ ] **Phase 8: Search + Keyboard Navigation** - Text search with real-time filtering, arrow key navigation, Enter to copy
- [ ] **Phase 9: Global Hotkey + Paste-on-Select** - Cmd+Shift+V summons history from any app, Enter pastes into previous app

### Phase 6: Screenshot Auto-Detection
**Goal**: Users never have to manually locate their screenshot folder -- the app detects it automatically and confirms during onboarding
**Depends on**: Phase 5
**Requirements**: SCRN-04, SCRN-05, SCRN-06
**Success Criteria** (what must be TRUE):
  1. On first launch, the app reads the macOS screenshot save location from system defaults and pre-fills it in the onboarding folder picker
  2. If the user has a custom screenshot location (e.g., ~/Pictures/Screenshots), that location is detected and shown -- not ~/Desktop
  3. If no custom screenshot location is configured in macOS, the app defaults to ~/Desktop as the watch directory
  4. User can still override the detected location during onboarding if desired
**Plans**: 1/1 complete

Plans:
- [x] 06-01-PLAN.md — Screenshot location detector, sandbox entitlement, and onboarding pre-fill UX

### Phase 7: Favorites + History Scale
**Goal**: Users can pin important clipboard items that never expire, and the history holds up to 500 items without performance degradation
**Depends on**: Phase 6
**Requirements**: FAV-01, FAV-02, FAV-03, FAV-04, HIST-01, HIST-02, HIST-03
**Success Criteria** (what must be TRUE):
  1. User can pin a clipboard item via context menu, and pinned items appear in a dedicated section at the top of the history list
  2. Pinned items survive history purges -- when the 500-item limit is reached, only unpinned items are auto-purged
  3. User can unpin an item and it returns to normal history behavior (subject to purge)
  4. Scrolling through 500 items is smooth with no visible stutter or lag
  5. Saving 500 items to disk does not cause the UI to freeze (debounced writes, no blocking the main thread)
**Plans**: 2/2 complete

Plans:
- [x] 07-01-PLAN.md — Data layer: isPinned model field, pin/unpin + pinned-aware purge, debounced save, NSCache thumbnails, 500-item settings
- [x] 07-02-PLAN.md — UI layer: sectioned Pinned/History layout, context menu pin action, pin icon overlay

### Phase 8: Search + Keyboard Navigation
**Goal**: Users can instantly find any item in their history by typing, and navigate the entire popover without touching the mouse
**Depends on**: Phase 7
**Requirements**: SRCH-01, SRCH-02, SRCH-03, KBNAV-01, KBNAV-02, KBNAV-03, KBNAV-04
**Success Criteria** (what must be TRUE):
  1. A search field at the top of the popover filters history items in real-time as the user types (case-insensitive text match)
  2. Clearing the search field restores the full history list including pinned items at the top
  3. Arrow keys move the selection highlight through items in the list, and the preview pane updates to show the selected item
  4. Pressing Enter on a selected item copies it to the clipboard
  5. Pressing Escape dismisses the popover (or clears the search field if text is present)
**Plans**: 2 plans

Plans:
- [ ] 08-01-PLAN.md — Search field with real-time filtering, text highlighting, and no-results state
- [ ] 08-02-PLAN.md — Keyboard navigation: arrow keys, Enter to copy, Escape, Tab focus management

### Phase 9: Global Hotkey + Paste-on-Select
**Goal**: Users can summon their clipboard history from any app with a keyboard shortcut and paste items directly without switching windows
**Depends on**: Phase 8
**Requirements**: ACCESS-01, ACCESS-02, ACCESS-03, ACCESS-04
**Success Criteria** (what must be TRUE):
  1. Pressing Cmd+Shift+V from any app opens the Copyhog popover with the search field focused and ready for typing
  2. User can customize the global hotkey in settings via a shortcut recorder
  3. Pressing Enter on a selected item pastes it directly into the previously active app (popover dismisses, Cmd+V is simulated)
  4. If Accessibility permission is not granted, Enter copies the item to clipboard only (no paste simulation) and a prompt guides the user to enable permissions
**Plans**: TBD

Plans:
- [ ] TBD (run /gsd:plan-phase 9 to break down)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 04.1 -> 04.2 -> 04.3 -> 5 -> 6 -> 7 -> 8 -> 9

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Capture Engine | v1.0 | 2/2 | Complete | 2026-02-21 |
| 2. Browse UI | v1.0 | 1/1 | Complete | 2026-02-21 |
| 3. Paste Actions | v1.0 | 2/2 | Complete | 2026-02-21 |
| 4. User Control | v1.1 | 1/1 | Complete | 2026-02-21 |
| 04.1 Settings Menu | v1.1 | 2/2 | Complete | 2026-02-21 |
| 04.2 Liquid Glass UI | v1.1 | 1/1 | Complete | 2026-02-22 |
| 04.3 App Store Readiness | v1.1 | 1/1 | Complete | 2026-02-21 |
| 5. Privacy & Compliance | v1.1 | 1/1 | Complete | 2026-02-21 |
| 6. Screenshot Auto-Detection | v1.2 | 1/1 | Complete | 2026-02-22 |
| 7. Favorites + History Scale | v1.2 | 2/2 | Complete | 2026-02-22 |
| 8. Search + Keyboard Navigation | v1.2 | 0/2 | Not started | - |
| 9. Global Hotkey + Paste-on-Select | v1.2 | 0/? | Not started | - |
