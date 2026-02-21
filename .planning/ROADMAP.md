# Roadmap: Copyhog

## Overview

Copyhog is a native macOS menu bar app that captures clipboard items and screenshots into a browsable history with instant re-paste. The roadmap delivers in three phases: first the invisible engine (menu bar shell, clipboard observer, screenshot watcher, persistent store), then the browsable UI (preview pane, item list, hover interaction), and finally the paste actions that close the loop (single-click copy, multi-select batch paste, drag-out).

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Capture Engine** - Menu bar shell, clipboard observer, screenshot watcher, and persistent item store
- [ ] **Phase 2: Browse UI** - Split-view popover with preview pane, item list, and hover interaction
- [ ] **Phase 3: Paste Actions** - Single-click copy, multi-select batch paste, and drag-out

## Phase Details

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
**Plans:** 2 plans

Plans:
- [ ] 01-01-PLAN.md — Xcode project scaffold, MenuBarExtra with popover, global hotkey, launch-at-login
- [ ] 01-02-PLAN.md — Clipboard observer, screenshot watcher, image store, persistent item store

### Phase 2: Browse UI
**Goal**: Users can visually browse their capture history and preview any item at full size
**Depends on**: Phase 1
**Requirements**: UI-01, UI-02, UI-03, UI-04
**Success Criteria** (what must be TRUE):
  1. The popover shows a scrollable list of captured items with 64x64 thumbnails (images) or 2-line text snippets, each with a relative timestamp
  2. Hovering over an item row updates the preview pane at the top to show the full-size image or full text
  3. When no items have been captured, a friendly empty state message is displayed instead of a blank screen
**Plans**: TBD

Plans:
- [ ] 02-01: Item list, preview pane, and empty state (UI-01, UI-02, UI-03, UI-04)

### Phase 3: Paste Actions
**Goal**: Users can get any captured item back into their workflow -- single click to copy, multi-select for batch paste, or drag directly into target apps
**Depends on**: Phase 2
**Requirements**: PASTE-01, PASTE-02, PASTE-03, PASTE-04
**Success Criteria** (what must be TRUE):
  1. Clicking an item row copies it to the system clipboard, ready to paste into any app
  2. Toggling multi-select mode shows checkboxes on rows, and the "Copy N items" button writes selected image file URLs to the pasteboard for batch paste into apps like Slack or Figma
  3. Items can be dragged out of the popover directly into target apps (text or image)
**Plans**: TBD

Plans:
- [ ] 03-01: Single-click paste and multi-select batch paste (PASTE-01, PASTE-02, PASTE-03)
- [ ] 03-02: Drag-out support (PASTE-04)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Capture Engine | 0/2 | Not started | - |
| 2. Browse UI | 0/1 | Not started | - |
| 3. Paste Actions | 0/2 | Not started | - |
