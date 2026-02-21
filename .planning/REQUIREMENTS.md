# Requirements: Copyhog

**Defined:** 2026-02-20
**Core Value:** Every screenshot and clipboard copy is captured and instantly accessible — no hunting, no lost items, no broken workflow.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### App Shell

- [ ] **SHELL-01**: App runs as a macOS menu bar utility with a hedgehog silhouette template icon
- [ ] **SHELL-02**: Clicking menu bar icon opens a split-view popover (~360x480px) anchored to the icon
- [ ] **SHELL-03**: Global hotkey (Shift+Up Arrow) toggles the popover open/closed
- [ ] **SHELL-04**: App launches at login and runs silently in background

### Clipboard Capture

- [ ] **CLIP-01**: App polls NSPasteboard.general.changeCount every 0.5s and captures new text content
- [ ] **CLIP-02**: App polls NSPasteboard.general.changeCount every 0.5s and captures new image content
- [ ] **CLIP-03**: Captured images are saved to ~/Library/Application Support/Copyhog/

### Screenshot Management

- [ ] **SCRN-01**: App watches the screenshot directory via FSEvents for new .png files
- [ ] **SCRN-02**: New screenshots are moved to ~/Documents/Screenies/
- [ ] **SCRN-03**: New screenshots are automatically copied to system clipboard

### Item Store

- [ ] **STOR-01**: ClipItem model stores id, type (text/image), content, thumbnail, filePath, timestamp
- [ ] **STOR-02**: Store holds max 20 items, auto-purges oldest when exceeded
- [ ] **STOR-03**: Store persists across app restarts

### Popover UI

- [ ] **UI-01**: Preview pane (top) shows full-size image or full text of highlighted item
- [ ] **UI-02**: Item list (bottom) shows scrollable rows with 64x64 thumbnails or 2-line text snippets + relative timestamps
- [ ] **UI-03**: Hovering an item row updates the preview pane
- [ ] **UI-04**: Empty state shows friendly message when no items captured yet

### Paste Actions

- [ ] **PASTE-01**: Single-clicking an item row copies it to the system clipboard
- [ ] **PASTE-02**: Multi-select mode toggleable via button, enables checkboxes on rows
- [ ] **PASTE-03**: "Copy N items" button writes selected image file URLs as NSPasteboardItem array to pasteboard
- [ ] **PASTE-04**: Items are draggable out of the popover into target apps via Transferable/NSItemProvider

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Capture

- **CAPT-01**: Copyhog-initiated screenshot capture via dedicated hotkey (skip desktop save)
- **CAPT-02**: Rich text clipboard capture (formatted text from Pages, emails)
- **CAPT-03**: File clipboard capture (files copied from Finder)

### Organization

- **ORG-01**: Search/filter within clipboard history
- **ORG-02**: Pin/favorite items to prevent auto-purge
- **ORG-03**: Configurable item retention limit (beyond 20)

### Sync

- **SYNC-01**: Clipboard sync across devices via iCloud

## Out of Scope

| Feature | Reason |
|---------|--------|
| Intercepting native screenshot shortcuts | Observer-only approach — non-invasive, keeps Cmd+Shift+3/4/5 working normally |
| Visual distinction between screenshots and copied images | User preference — not needed |
| Configurable hotkey | Shift+Up Arrow fixed for v1, configurable in v2 |
| Windows/Linux support | macOS-only, uses native APIs (MenuBarExtra, NSPasteboard, FSEvents) |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SHELL-01 | Phase 1 | Pending |
| SHELL-02 | Phase 1 | Pending |
| SHELL-03 | Phase 1 | Pending |
| SHELL-04 | Phase 1 | Pending |
| CLIP-01 | Phase 1 | Pending |
| CLIP-02 | Phase 1 | Pending |
| CLIP-03 | Phase 1 | Pending |
| SCRN-01 | Phase 1 | Pending |
| SCRN-02 | Phase 1 | Pending |
| SCRN-03 | Phase 1 | Pending |
| STOR-01 | Phase 1 | Pending |
| STOR-02 | Phase 1 | Pending |
| STOR-03 | Phase 1 | Pending |
| UI-01 | Phase 2 | Pending |
| UI-02 | Phase 2 | Pending |
| UI-03 | Phase 2 | Pending |
| UI-04 | Phase 2 | Pending |
| PASTE-01 | Phase 3 | Pending |
| PASTE-02 | Phase 3 | Pending |
| PASTE-03 | Phase 3 | Pending |
| PASTE-04 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 21 total
- Mapped to phases: 21
- Unmapped: 0

---
*Requirements defined: 2026-02-20*
*Last updated: 2026-02-20 after roadmap creation*
