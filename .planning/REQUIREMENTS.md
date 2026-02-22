# Requirements: Copyhog

**Defined:** 2026-02-20
**Core Value:** Every screenshot and clipboard copy is captured and instantly accessible -- no hunting, no lost items, no broken workflow.

## v1.0 Requirements (Complete)

All v1.0 requirements shipped. See MILESTONES.md for details.

### App Shell

- [x] **SHELL-01**: App runs as a macOS menu bar utility with a hedgehog silhouette template icon
- [x] **SHELL-02**: Clicking menu bar icon opens a split-view popover (~360x480px) anchored to the icon
- [x] **SHELL-03**: App launches at login and runs silently in background

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

### Item Management

- [x] **MGMT-01**: User can delete a single item from the clipboard history list
- [x] **MGMT-02**: User can wipe all items from clipboard history via a "Hog Wipe" action with confirmation

## v1.2 Requirements

Requirements for milestone v1.2 (Power User Essentials). Each maps to roadmap phases.

### Global Access

- [ ] **ACCESS-01**: User can press a global keyboard shortcut (default Cmd+Shift+V) to summon the clipboard history popover from any app
- [ ] **ACCESS-02**: User can customize the global hotkey via a shortcut recorder in settings
- [ ] **ACCESS-03**: When user selects an item and presses Enter, the item is pasted directly into the previously active app (paste-on-select)
- [ ] **ACCESS-04**: If Accessibility permission is not granted, paste-on-select falls back to copy-only mode with a prompt to enable permissions

### Search

- [ ] **SRCH-01**: User can type in a search field at the top of the popover to filter clipboard history by text content
- [ ] **SRCH-02**: Search results update in real-time as the user types (debounced)
- [ ] **SRCH-03**: When search field is cleared, the full history list is restored

### Keyboard Navigation

- [ ] **KBNAV-01**: User can press arrow keys to move selection through items in the popover
- [ ] **KBNAV-02**: User can press Enter on a selected item to copy it (or paste-on-select if enabled)
- [ ] **KBNAV-03**: User can press Escape to dismiss the popover
- [ ] **KBNAV-04**: When popover opens via hotkey, the search field is focused and ready for typing

### Favorites

- [ ] **FAV-01**: User can pin/favorite a clipboard item via context menu or keyboard shortcut
- [ ] **FAV-02**: Pinned items are displayed in a dedicated section at the top of the history list
- [ ] **FAV-03**: Pinned items are never auto-purged regardless of history limit
- [ ] **FAV-04**: User can unpin an item to return it to normal history behavior

### History Scale

- [ ] **HIST-01**: History limit is raised to support up to 500 items
- [ ] **HIST-02**: Persistence is performant at 500 items (debounced saves, no UI stutter)
- [ ] **HIST-03**: Thumbnail images are cached in memory (NSCache) for smooth scrolling at scale

### Screenshot Auto-Detection

- [ ] **SCRN-04**: App auto-detects the macOS screenshot save location from system defaults on first launch
- [ ] **SCRN-05**: Onboarding pre-fills the detected screenshot folder, allowing user to confirm or change
- [ ] **SCRN-06**: If no custom screenshot location is set, app defaults to ~/Desktop

## Future Requirements

Deferred to future release. Tracked but not in current roadmap.

### Capture

- **CAPT-01**: Copyhog-initiated screenshot capture via dedicated hotkey (skip desktop save)
- **CAPT-02**: Rich text clipboard capture (formatted text from Pages, emails)
- **CAPT-03**: File clipboard capture (files copied from Finder)

### Organization

- **ORG-01**: Fuzzy search / approximate matching in clipboard history
- **ORG-02**: Pin categories/folders for organizing favorites
- **ORG-03**: Search across image OCR text

### Sync

- **SYNC-01**: Clipboard sync across devices via iCloud

## Out of Scope

| Feature | Reason |
|---------|--------|
| Intercepting native screenshot shortcuts | Observer-only approach -- non-invasive |
| Visual distinction between screenshots and copied images | User preference -- not needed |
| Fuzzy search | Text search is sufficient for v1.2; exact match covers 90% of use cases |
| Pin categories/folders | Simple pin/unpin is sufficient; organization adds complexity |
| Snippet/template system | Beyond clipboard history scope |
| iCloud sync | Local-only for now |
| Windows/Linux support | macOS-only, uses native APIs |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SHELL-01 | Phase 1 | Complete |
| SHELL-02 | Phase 1 | Complete |
| SHELL-03 | Phase 1 | Complete |
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
| MGMT-01 | Phase 4 | Complete |
| MGMT-02 | Phase 4 | Complete |
| ACCESS-01 | Phase 9 | Pending |
| ACCESS-02 | Phase 9 | Pending |
| ACCESS-03 | Phase 9 | Pending |
| ACCESS-04 | Phase 9 | Pending |
| SRCH-01 | Phase 8 | Pending |
| SRCH-02 | Phase 8 | Pending |
| SRCH-03 | Phase 8 | Pending |
| KBNAV-01 | Phase 8 | Pending |
| KBNAV-02 | Phase 8 | Pending |
| KBNAV-03 | Phase 8 | Pending |
| KBNAV-04 | Phase 8 | Pending |
| FAV-01 | Phase 7 | Pending |
| FAV-02 | Phase 7 | Pending |
| FAV-03 | Phase 7 | Pending |
| FAV-04 | Phase 7 | Pending |
| HIST-01 | Phase 7 | Pending |
| HIST-02 | Phase 7 | Pending |
| HIST-03 | Phase 7 | Pending |
| SCRN-04 | Phase 6 | Pending |
| SCRN-05 | Phase 6 | Pending |
| SCRN-06 | Phase 6 | Pending |

**Coverage:**
- v1.0 requirements: 20 total (all complete)
- v1.1 requirements: 2 total (all complete)
- v1.2 requirements: 21 total
- Mapped to phases: 21/21
- Unmapped: 0

---
*Requirements defined: 2026-02-20*
*Last updated: 2026-02-21 after v1.2 roadmap creation*
