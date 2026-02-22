# Roadmap: Copyhog

## Milestones

- v1.0 MVP - Phases 1-3 (shipped 2026-02-21)
- v1.1 Polish & Control - Phase 4 (in progress)
- v1.2 Power User Essentials - Phases 6-9 (planned)

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

### Phase 1: Capture Engine
**Goal**: The app runs silently in the menu bar, automatically capturing every clipboard copy and screenshot into a persistent local store
**Depends on**: Nothing (first phase)
**Requirements**: SHELL-01, SHELL-02, SHELL-03, SHELL-04, CLIP-01, CLIP-02, CLIP-03, SCRN-01, SCRN-02, SCRN-03, STOR-01, STOR-02, STOR-03
**Success Criteria** (what must be TRUE):
  1. A hedgehog icon appears in the macOS menu bar and clicking it opens an empty popover window (~360x480px)
  2. Clicking the menu bar icon opens the popover
  3. Copying text or an image anywhere on the system creates a new entry in the item store within 1 second
  4. Taking a screenshot (Cmd+Shift+3/4) results in the file appearing in ~/Documents/Screenies/ and the image being copied to the system clipboard
  5. The store holds exactly 20 items max, purging the oldest when exceeded, and items survive an app restart
**Plans:** 2/2 complete

Plans:
- [x] 01-01-PLAN.md — Xcode project scaffold, MenuBarExtra with popover, launch-at-login
- [x] 01-02-PLAN.md — Clipboard observer, screenshot watcher, image store, persistent item store

### Phase 2: Browse UI
**Goal**: Users can visually browse their capture history and preview any item at full size
**Depends on**: Phase 1
**Requirements**: UI-01, UI-02, UI-03, UI-04
**Success Criteria** (what must be TRUE):
  1. The popover shows a scrollable list of captured items with 64x64 thumbnails (images) or 2-line text snippets, each with a relative timestamp
  2. Hovering over an item row updates the preview pane at the top to show the full-size image or full text
  3. When no items have been captured, a friendly empty state message is displayed instead of a blank screen
**Plans:** 1/1 complete

Plans:
- [x] 02-01-PLAN.md — Preview pane, item list with 64x64 thumbnails, hover-driven preview, and empty state

### Phase 3: Paste Actions
**Goal**: Users can get any captured item back into their workflow -- single click to copy, multi-select for batch paste, or drag directly into target apps
**Depends on**: Phase 2
**Requirements**: PASTE-01, PASTE-02, PASTE-03, PASTE-04
**Success Criteria** (what must be TRUE):
  1. Clicking an item row copies it to the system clipboard, ready to paste into any app
  2. Toggling multi-select mode shows checkboxes on rows, and the "Copy N items" button writes selected image file URLs to the pasteboard for batch paste into apps like Slack or Figma
  3. Items can be dragged out of the popover directly into target apps (text or image)
**Plans:** 2/2 complete

Plans:
- [x] 03-01-PLAN.md — Single-click copy-to-clipboard and multi-select batch paste
- [x] 03-02-PLAN.md — Drag-out support via Transferable and .draggable

</details>

## v1.1 Polish & Control

**Milestone Goal:** Give the user full control over their clipboard history -- let them delete individual items and wipe everything clean.

- [ ] **Phase 4: User Control** - Single-item delete and full history wipe

## Phase Details

### Phase 4: User Control
**Goal**: Users have full control over their clipboard history -- removing items at will
**Depends on**: Phase 3
**Requirements**: MGMT-01, MGMT-02
**Success Criteria** (what must be TRUE):
  1. User can delete a single item from the history list and it disappears immediately from both the UI and the persistent store
  2. User can trigger "Hog Wipe" and after confirming, all items are removed from the history list and persistent store
  3. After a Hog Wipe, the popover shows the empty state message
**Plans:** 1 plan

Plans:
- [ ] 04-01-PLAN.md — Single-item delete and Hog Wipe with confirmation

### Phase 04.1: Settings menu with version display, attribution, and relocated actions (INSERTED)

**Goal:** Users can access a settings/gear menu that displays the app version, credits/attribution, and houses the Quit and Hog Wipe actions (relocated from the main popover toolbar to declutter it)
**Depends on:** Phase 4
**Requirements:** SETTINGS-01, SETTINGS-02, SETTINGS-03, SETTINGS-04
**Success Criteria** (what must be TRUE):
  1. A gear icon in the popover toolbar opens a settings dropdown menu
  2. The settings menu shows the app version and attribution/credits
  3. Hog Wipe and Quit Copyhog actions are accessible from the settings menu (not the main toolbar/popover)
  4. The main popover toolbar is decluttered (only multi-select toggle + gear icon)
**Plans:** 1/1 plans complete

Plans:
- [x] 04.1-01-PLAN.md — Settings menu with version, attribution, relocated Hog Wipe and Quit

### Phase 04.2: Liquid glass UI redesign (INSERTED)

**Goal:** Transform the popover from a flat UI into a warm, translucent liquid glass aesthetic — translucent materials, elevated preview pane, floating toolbar, glow hover effects, copy confirmation, and hedgehog-themed empty state
**Depends on:** Phase 4
**Plans:** 1/2 plans executed

Plans:
- [ ] 04.2-01-PLAN.md — Glass popover shell, floating toolbar, elevated preview pane
- [ ] 04.2-02-PLAN.md — Glass item rows with glow hover, copy confirmation, warm empty state

### Phase 04.3: Remaining App Store readiness (INSERTED)

**Goal:** Resolve all remaining App Store rejection risks so the app passes review on first submission
**Depends on:** Phase 04.1
**Requirements:** STORE-01 through STORE-06
**Success Criteria** (what must be TRUE):
  1. ScreenshotWatcher uses security-scoped bookmarks for ~/Desktop and ~/Documents/Screenies/ so file access survives app restart
  2. First-run onboarding prompts user to grant folder access via NSOpenPanel, saving bookmarks persistently
  3. NSAccessibilityUsageDescription is updated (hotkeys were removed — current string is misleading and will cause rejection)
  4. `com.apple.security.automation.apple-events` entitlement is removed (no longer needed since hotkeys were removed)
  5. App Store metadata is prepared: privacy nutrition labels (clipboard, file access), category, age rating
  6. Build archives and exports cleanly with `xcodebuild archive` using App Store distribution profile
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd:plan-phase 04.3 to break down)

### Phase 5: Privacy — App Store Compliance + Configurable History

**Goal:** Add required privacy manifest, pasteboard usage description, launch-at-login toggle, and configurable history size for App Store compliance
**Depends on:** Phase 04.1
**Success Criteria** (what must be TRUE):
  1. PrivacyInfo.xcprivacy declares FileTimestamp (C617.1) and UserDefaults (CA92.1) APIs, no tracking, no collected data
  2. NSPasteboardUsageDescription is set in Info.plist
  3. Launch at Login is a user-controlled toggle (default: off) in the settings menu
  4. History size is configurable (10-50) via settings menu picker, persisted in UserDefaults
**Plans:** 1/1 complete

Plans:
- [x] 05-01-PLAN.md — Privacy manifest, pasteboard description, launch toggle, history size picker

---

## v1.2 Power User Essentials

**Milestone Goal:** Make Copyhog a keyboard-driven power tool -- instant access from anywhere, searchable history, pinned favorites, and zero-config screenshot detection.

- [x] **Phase 6: Screenshot Auto-Detection** - Auto-detect macOS screenshot save location, eliminating manual folder setup (completed 2026-02-22)
- [ ] **Phase 7: Favorites + History Scale** - Pinned items, 500-item history, debounced persistence, thumbnail caching
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
**Plans**: 1 plan

Plans:
- [ ] 06-01-PLAN.md — Screenshot location detector, sandbox entitlement, and onboarding pre-fill UX

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
**Plans**: 2 plans

Plans:
- [ ] 07-01-PLAN.md — Data layer: isPinned model field, pin/unpin + pinned-aware purge, debounced save, NSCache thumbnails, 500-item settings
- [ ] 07-02-PLAN.md — UI layer: sectioned Pinned/History layout, context menu pin action, pin icon overlay

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
**Plans**: TBD

Plans:
- [ ] TBD (run /gsd:plan-phase 8 to break down)

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
| 4. User Control | v1.1 | 0/1 | Not started | - |
| 04.1 Settings Menu | v1.1 | 1/1 | Complete | 2026-02-21 |
| 04.2 Liquid Glass UI | v1.1 | 1/2 | In Progress | - |
| 04.3 App Store Readiness | v1.1 | 0/? | Not started | - |
| 5. Privacy & Compliance | v1.1 | 1/1 | Complete | 2026-02-21 |
| 6. Screenshot Auto-Detection | v1.2 | Complete    | 2026-02-22 | - |
| 7. Favorites + History Scale | v1.2 | 0/2 | Not started | - |
| 8. Search + Keyboard Navigation | v1.2 | 0/? | Not started | - |
| 9. Global Hotkey + Paste-on-Select | v1.2 | 0/? | Not started | - |
