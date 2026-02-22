# Requirements: Copyhog

**Defined:** 2026-02-21
**Core Value:** Every screenshot and clipboard copy is captured and instantly accessible -- no hunting, no lost items, no broken workflow.

## v1.2 Requirements

Requirements for milestone v1.2 (Power User Essentials). Each maps to roadmap phases.

### Screenshot Auto-Detection

- [x] **SCRN-04**: App auto-detects the macOS screenshot save location from system defaults on first launch
- [x] **SCRN-05**: Onboarding pre-fills the detected screenshot folder, allowing user to confirm or change
- [x] **SCRN-06**: If no custom screenshot location is set, app defaults to ~/Desktop

### History Scale

- [x] **HIST-01**: History limit is raised to support up to 500 items
- [x] **HIST-02**: Persistence is performant at 500 items (debounced saves, no UI stutter)
- [x] **HIST-03**: Thumbnail images are cached in memory (NSCache) for smooth scrolling at scale

### Search

- [x] **SRCH-01**: User can type in a search field at the top of the popover to filter clipboard history by text content
- [x] **SRCH-02**: Search results update in real-time as the user types (debounced)
- [x] **SRCH-03**: When search field is cleared, the full history list is restored

### Keyboard Navigation

- [x] **KBNAV-01**: User can press arrow keys to move selection through items in the popover
- [x] **KBNAV-02**: User can press Enter on a selected item to copy it (or paste-on-select if enabled)
- [x] **KBNAV-03**: User can press Escape to dismiss the popover
- [x] **KBNAV-04**: When popover opens via hotkey, the search field is focused and ready for typing

### Global Access

- [ ] **ACCESS-01**: User can press a global keyboard shortcut (default Cmd+Shift+V) to summon the clipboard history popover from any app
- [ ] **ACCESS-02**: User can customize the global hotkey via a shortcut recorder in settings
- [ ] **ACCESS-03**: When user selects an item and presses Enter, the item is pasted directly into the previously active app (paste-on-select)
- [ ] **ACCESS-04**: If Accessibility permission is not granted, paste-on-select falls back to copy-only mode with a prompt to enable permissions

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
| Pin/favorites system | Removed — feature wasn't successful |
| Snippet/template system | Beyond clipboard history scope |
| iCloud sync | Local-only for now |
| Windows/Linux support | macOS-only, uses native APIs |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCRN-04 | Phase 6 | Complete |
| SCRN-05 | Phase 6 | Complete |
| SCRN-06 | Phase 6 | Complete |
| HIST-01 | Phase 7 | Complete |
| HIST-02 | Phase 7 | Complete |
| HIST-03 | Phase 7 | Complete |
| SRCH-01 | Phase 8 | Complete |
| SRCH-02 | Phase 8 | Complete |
| SRCH-03 | Phase 8 | Complete |
| KBNAV-01 | Phase 8 | Complete |
| KBNAV-02 | Phase 8 | Complete |
| KBNAV-03 | Phase 8 | Complete |
| KBNAV-04 | Phase 8 | Complete |
| ACCESS-01 | Phase 9 | Pending |
| ACCESS-02 | Phase 9 | Pending |
| ACCESS-03 | Phase 9 | Pending |
| ACCESS-04 | Phase 9 | Pending |

**Coverage:**
- v1.2 requirements: 17 total
- Complete: 13 (Phases 6-8)
- Pending: 4 (Phase 9)
- Mapped to phases: 17/17
- Unmapped: 0

---
*Requirements defined: 2026-02-21*
*Last updated: 2026-02-22 after v1.1 milestone archive*
