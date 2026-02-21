# Roadmap: Copyhog

## Milestones

- v1.0 MVP - Phases 1-3 (shipped 2026-02-21)
- v1.1 Polish & Control - Phase 4 (in progress)

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
  2. Pressing Shift+Up Arrow toggles the popover open and closed from any app
  3. Copying text or an image anywhere on the system creates a new entry in the item store within 1 second
  4. Taking a screenshot (Cmd+Shift+3/4) results in the file appearing in ~/Documents/Screenies/ and the image being copied to the system clipboard
  5. The store holds exactly 20 items max, purging the oldest when exceeded, and items survive an app restart
**Plans:** 2/2 complete

Plans:
- [x] 01-01-PLAN.md — Xcode project scaffold, MenuBarExtra with popover, global hotkey, launch-at-login
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

**Milestone Goal:** Give the user full control over their clipboard history -- fix the broken hotkey, let them delete individual items, and wipe everything clean.

- [ ] **Phase 4: User Control** - Global hotkey fix, single-item delete, and full history wipe

## Phase Details

### Phase 4: User Control
**Goal**: Users have full control over the Copyhog popover and their clipboard history -- summoning it from anywhere and removing items at will
**Depends on**: Phase 3
**Requirements**: KEY-01, MGMT-01, MGMT-02
**Success Criteria** (what must be TRUE):
  1. User can press Shift+Ctrl+C from any app and the Copyhog popover toggles open or closed reliably
  2. User can delete a single item from the history list and it disappears immediately from both the UI and the persistent store
  3. User can trigger "Hog Wipe" and after confirming, all items are removed from the history list and persistent store
  4. After a Hog Wipe, the popover shows the empty state message
**Plans**: TBD

Plans:
- [ ] (to be planned)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Capture Engine | v1.0 | 2/2 | Complete | 2026-02-21 |
| 2. Browse UI | v1.0 | 1/1 | Complete | 2026-02-21 |
| 3. Paste Actions | v1.0 | 2/2 | Complete | 2026-02-21 |
| 4. User Control | v1.1 | 0/? | Not started | - |
