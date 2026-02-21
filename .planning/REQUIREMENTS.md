# Requirements: Copyhog

**Defined:** 2026-02-20
**Core Value:** Every screenshot and clipboard copy is captured and instantly accessible — no hunting, no lost items, no broken workflow.

## v1.0 Requirements (Complete)

All v1.0 requirements shipped. See MILESTONES.md for details.

### App Shell

- [x] **SHELL-01**: App runs as a macOS menu bar utility with a hedgehog silhouette template icon
- [x] **SHELL-02**: Clicking menu bar icon opens a split-view popover (~360x480px) anchored to the icon
- [x] **SHELL-03**: Global hotkey (Shift+Up Arrow) toggles the popover open/closed
- [x] **SHELL-04**: App launches at login and runs silently in background

### Clipboard Capture

- [x] **CLIP-01**: App polls NSPasteboard.general.changeCount every 0.5s and captures new text content
- [x] **CLIP-02**: App polls NSPasteboard.general.changeCount every 0.5s and captures new image content
- [x] **CLIP-03**: Captured images are saved to ~/Library/Application Support/Copyhog/

### Screenshot Management

- [x] **SCRN-01**: App watches the screenshot directory via FSEvents for new .png files
- [x] **SCRN-02**: New screenshots are moved to ~/Documents/Screenies/
- [x] **SCRN-03**: New screenshots are automatically copied to system clipboard

### Item Store

- [x] **STOR-01**: ClipItem model stores id, type (text/image), content, thumbnail, filePath, timestamp
- [x] **STOR-02**: Store holds max 20 items, auto-purges oldest when exceeded
- [x] **STOR-03**: Store persists across app restarts

### Popover UI

- [x] **UI-01**: Preview pane (top) shows full-size image or full text of highlighted item
- [x] **UI-02**: Item list (bottom) shows scrollable rows with 64x64 thumbnails or 2-line text snippets + relative timestamps
- [x] **UI-03**: Hovering an item row updates the preview pane
- [x] **UI-04**: Empty state shows friendly message when no items captured yet

### Paste Actions

- [x] **PASTE-01**: Single-clicking an item row copies it to the system clipboard
- [x] **PASTE-02**: Multi-select mode toggleable via button, enables checkboxes on rows
- [x] **PASTE-03**: "Copy N items" button writes selected image file URLs as NSPasteboardItem array to pasteboard
- [x] **PASTE-04**: Items are draggable out of the popover into target apps via Transferable/NSItemProvider

## v1.1 Requirements

Requirements for milestone v1.1 (Polish & Control). Each maps to roadmap phases.

### Hotkey

- [ ] **KEY-01**: User can press Shift+Ctrl+C from any app to toggle the Copyhog popover open and closed

### Item Management

- [ ] **MGMT-01**: User can delete a single item from the clipboard history list
- [ ] **MGMT-02**: User can wipe all items from clipboard history via a "Hog Wipe" action with confirmation

## Future Requirements

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
| Intercepting native screenshot shortcuts | Observer-only approach — non-invasive |
| Visual distinction between screenshots and copied images | User preference — not needed |
| Customizable hotkey | Fixed Shift+Ctrl+C is sufficient for v1.1 |
| Undo delete | 20-item list is simple enough; no undo needed |
| Selective multi-delete | Single delete + full wipe covers all cases |
| Windows/Linux support | macOS-only, uses native APIs |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SHELL-01 | Phase 1 | Complete |
| SHELL-02 | Phase 1 | Complete |
| SHELL-03 | Phase 1 | Complete |
| SHELL-04 | Phase 1 | Complete |
| CLIP-01 | Phase 1 | Complete |
| CLIP-02 | Phase 1 | Complete |
| CLIP-03 | Phase 1 | Complete |
| SCRN-01 | Phase 1 | Complete |
| SCRN-02 | Phase 1 | Complete |
| SCRN-03 | Phase 1 | Complete |
| STOR-01 | Phase 1 | Complete |
| STOR-02 | Phase 1 | Complete |
| STOR-03 | Phase 1 | Complete |
| UI-01 | Phase 2 | Complete |
| UI-02 | Phase 2 | Complete |
| UI-03 | Phase 2 | Complete |
| UI-04 | Phase 2 | Complete |
| PASTE-01 | Phase 3 | Complete |
| PASTE-02 | Phase 3 | Complete |
| PASTE-03 | Phase 3 | Complete |
| PASTE-04 | Phase 3 | Complete |
| KEY-01 | Phase 4 | Pending |
| MGMT-01 | Phase 4 | Pending |
| MGMT-02 | Phase 4 | Pending |

**Coverage:**
- v1.0 requirements: 21 total (all complete)
- v1.1 requirements: 3 total
- Mapped to phases: 3/3
- Unmapped: 0

---
*Requirements defined: 2026-02-20*
*Last updated: 2026-02-21 after v1.1 roadmap creation*
