# Feature Research

**Domain:** macOS clipboard manager -- power user features (v1.2)
**Researched:** 2026-02-21
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features every serious clipboard manager has. Missing any of these and power users will switch to Maccy or Paste within a day.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Global hotkey to summon | Every competitor has this (Maccy: Cmd+Shift+C, Paste: Cmd+Shift+V). Without it, clicking the menu bar icon is too slow for power users. This is THE feature that makes clipboard managers useful. | MEDIUM | Use `sindresorhus/KeyboardShortcuts` SPM package -- it is Mac App Store compatible, sandboxed, SwiftUI-native, and handles the Carbon API deprecation mess. Default to Cmd+Shift+V (matches Paste convention). Must dismiss popover on second press (toggle behavior). |
| Search/filter history | With 500+ items, browsing is useless without search. Maccy, CleanClip, Paste all have instant search-as-you-type. Users type to filter, not scroll. | LOW | Filter the existing `items` array by `content` substring match (case-insensitive). Only text items are searchable -- images should remain visible when no search query is active. Add a TextField at the top of PopoverContent. Auto-focus the search field when popover appears. |
| Keyboard navigation | Arrow keys to move selection, Enter to copy-and-paste. Every competitor does this. Mouse-only interaction is a deal-breaker for power users. | MEDIUM | Up/Down arrows move selection highlight through item list. Enter copies selected item to clipboard. This is SwiftUI List selection binding -- `.onKeyPress` or custom key handling. Must work with search results too. |
| Large history (500+) | Maccy defaults to 200 (configurable up to unlimited). ClipPocket handles 10,000+. A 20-50 item cap is a toy. | MEDIUM | Current JSON file persistence will not scale well at 500+ items with images. Each save serializes the entire array. Need to either: (a) keep JSON but only write metadata (paths, not data) -- which the current model already does, or (b) migrate to SQLite/SwiftData for indexed queries. Recommendation: keep JSON for now since ClipItem is already just metadata pointers (content strings + file paths). At 500 items of metadata, JSON is fine. The bottleneck is image storage, which is already file-based. Raise `maxItems` cap to 500 in settings (slider range 10-500). |

### Differentiators (Competitive Advantage)

Features that set Copyhog apart. Not all competitors have these, and they add real value.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Paste-on-select (Enter pastes into previous app) | Most clipboard managers just copy to clipboard and leave you to Cmd+V yourself. Maccy offers Option+Enter to paste directly. This is the "magic" -- select an item and it instantly pastes into whatever app you were using before summoning Copyhog. Requires: (1) dismiss popover, (2) write to clipboard, (3) simulate Cmd+V via CGEvent. | HIGH | Requires Accessibility permission (System Settings > Privacy & Security > Accessibility). Use CGEvent to post keyDown/keyUp for Cmd+V to the cgSessionEventTap. Maccy's open-source implementation is the reference pattern. Must handle the timing: dismiss popover first, brief delay (~100ms), then simulate paste. Without Accessibility permission, fall back to copy-only (no paste simulation). Show permission prompt on first use. |
| ~~Pinned/favorited items~~ | ~~Removed — feature wasn't successful. Pin/favorites functionality has been stripped from the codebase.~~ | - | - |
| Auto-detect screenshot location | Current setup requires manual folder selection via onboarding. Users who change their screenshot location (or use the default Desktop) have to redo setup. Reading `com.apple.screencapture` UserDefaults eliminates this friction entirely. | LOW | Read `UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")`. If nil, default to `~/Desktop`. If set, use that path. Eliminates the need for BookmarkManager's screenshot source bookmark on first launch -- can auto-resolve. Still need security-scoped bookmark for sandbox access, but can pre-fill the path in the folder picker or auto-request access. Reduces onboarding from 2 folder picks to 1 (just the Screenies destination). |
| Customizable hotkey | Let users change the global shortcut in settings. KeyboardShortcuts package includes a SwiftUI `Recorder` component for this. Maccy and Paste both allow customization. | LOW | `KeyboardShortcuts.Recorder` SwiftUI view in settings. Ships with sensible default (Cmd+Shift+V) but lets users avoid conflicts with other apps. Nearly free if using the KeyboardShortcuts package. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems. Explicitly do NOT build these.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Snippet/template system with placeholders | Power users want reusable text with variables like `{{date}}` or `{{name}}` | Scope creep -- turns clipboard manager into a text expansion tool (TextExpander, Raycast territory). Doubles the codebase complexity. Pinned items cover 80% of the use case. | Use pinned items for static boilerplate. Recommend TextExpander or Raycast for dynamic snippets. |
| iCloud sync across devices | Users with multiple Macs want shared clipboard history | Massively increases complexity (conflict resolution, data schema versioning, image sync bandwidth). Apple's Universal Clipboard already handles single-item cross-device paste. | Stay local-only. Universal Clipboard handles the real-time case. If users need shared snippets, that is a different product. |
| Rich text / HTML clipboard types | Some users copy formatted text from web pages | Doubles the clipboard type handling, storage complexity, and preview rendering. Most paste targets strip formatting anyway. | Capture as plain text. If the user copies rich text, store the plain text representation. Images are already handled. |
| Floating window mode (always-on-top panel) | Some users want clipboard history visible at all times | Conflicts with Copyhog's menu bar app identity. Floating panels consume screen space, create window management conflicts, and fight with Stage Manager. | Keep the popover pattern. The global hotkey makes it instant to summon and dismiss -- no need for permanent visibility. |
| Regex/advanced search | Power users want regex or fuzzy matching in search | Overkill for clipboard history search. Simple substring match covers 95% of use cases. Regex adds UI complexity (error states, escape characters) with minimal benefit. | Simple case-insensitive substring search. If needed later, add fuzzy matching (much more user-friendly than regex). |
| Auto-paste most recent on Cmd+V override | Intercept system Cmd+V to show clipboard history instead | Breaks every user's muscle memory. Cmd+V must always paste the current clipboard contents. Intercepting it is hostile UX. | Use a distinct hotkey (Cmd+Shift+V) that does not conflict with standard paste. |

## Feature Dependencies

```
[Global Hotkey]
    |
    +--enables--> [Keyboard Navigation] (navigation only useful if keyboard-summoned)
    |                 |
    |                 +--enables--> [Paste-on-Select] (Enter key triggers paste flow)
    |
    +--enables--> [Search/Filter] (search field auto-focused on hotkey summon)

[Large History (500+)]
    |
    +--requires--> [Search/Filter] (browsing 500 items without search is useless)

[Pinned Items]
    |
    +--requires--> [Large History] (pinned items only matter when items get purged)
    |
    +--enhances--> [Search/Filter] (pinned items should appear in search results)

[Auto-detect Screenshot Location]
    (independent -- no dependencies, can be built in any order)

[Customizable Hotkey]
    +--enhances--> [Global Hotkey] (nice-to-have on top of default hotkey)
```

### Dependency Notes

- **Keyboard Navigation requires Global Hotkey:** If the user summons Copyhog via hotkey, they are already on the keyboard. Navigation must work immediately without reaching for the mouse.
- **Paste-on-Select requires Keyboard Navigation:** The Enter-to-paste flow depends on having a selected item via arrow key navigation.
- **Search requires Large History:** At 20 items, search is unnecessary. At 500, it is essential. Ship them together.
- **Pinned Items require Large History:** Pinning only matters when items get purged. With a 20-item cap, users hit the pin limit immediately. With 500, pins are the "keep forever" escape valve.
- **Auto-detect Screenshot Location is independent:** Can be built at any point. No dependencies on other features.

## MVP Definition (v1.2)

### Must Ship (Core of v1.2)

- [x] **Global hotkey (Cmd+Shift+V)** -- the single highest-value feature. Transforms Copyhog from "nice menu bar toy" to "essential daily tool."
- [x] **Search/filter** -- required for large history to be usable.
- [x] **Keyboard navigation (arrow keys + Enter to copy)** -- natural extension of hotkey workflow.
- [x] **Large history (500 items)** -- raise the cap, no storage migration needed.

### Should Ship (Strong v1.2)

- [ ] **Paste-on-select** -- paste directly into previous app on Enter. Requires Accessibility permission. HIGH value but adds permission complexity.
- [x] ~~**Pinned items**~~ -- removed, feature wasn't successful
- [ ] **Auto-detect screenshot location** -- low effort, removes onboarding friction.

### Defer (v1.3+)

- [ ] **Customizable hotkey** -- nice-to-have, but default Cmd+Shift+V works for most users. Add when users request it.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Global hotkey (Cmd+Shift+V) | HIGH | MEDIUM | P1 |
| Search/filter | HIGH | LOW | P1 |
| Keyboard navigation | HIGH | MEDIUM | P1 |
| Large history (500 items) | HIGH | LOW | P1 |
| Paste-on-select | HIGH | HIGH | P1 |
| ~~Pinned items~~ | - | - | Removed |
| Auto-detect screenshot location | MEDIUM | LOW | P2 |
| Customizable hotkey | LOW | LOW | P3 |

**Priority key:**
- P1: Must have for v1.2 launch -- these together create the "keyboard-driven power tool" identity
- P2: Should have, add if time permits within v1.2
- P3: Nice to have, defer to v1.3

## Competitor Feature Analysis

| Feature | Maccy (free, open source) | Paste ($3.99/mo subscription) | CleanClip ($12.99 one-time) | Copyhog (our approach) |
|---------|--------------------------|-------------------------------|----------------------------|----------------------|
| Global hotkey | Cmd+Shift+C (customizable) | Cmd+Shift+V (customizable) | Cmd+; (customizable) | Cmd+Shift+V (default), customizable later |
| Search | Instant type-to-search | Search-as-you-type | Type-to-search + smart lists | Substring filter in search bar |
| Keyboard nav | Full arrow key + Enter | Full keyboard support | Tab/arrows + Enter | Arrow keys + Enter |
| Paste-on-select | Option+Enter to paste | Click/Enter pastes directly | Enter pastes directly | Enter pastes directly (with Accessibility) |
| Pinned items | Option+P to pin, stays on top | Pinboard with lists | Favorites + smart lists | Pin toggle, sorted to top |
| History limit | 200 default, unlimited option | Unlimited | Unlimited | 500 default cap |
| Screenshot integration | None | None | None | Auto-detect + auto-copy (unique differentiator) |
| Price | Free | $3.99/mo | $12.99 | Free |

**Copyhog's unique angle:** Screenshot integration is the differentiator no competitor has. The auto-detect screenshot location feature strengthens this -- zero-config screenshot capture is genuinely novel in this space. All other features (hotkey, search, keyboard nav, pins) are table stakes that need to be solid but do not need to be best-in-class.

## Sources

- [Maccy - GitHub](https://github.com/p0deje/Maccy) -- open source reference implementation, Clipboard.swift for CGEvent paste simulation (HIGH confidence)
- [KeyboardShortcuts by sindresorhus](https://github.com/sindresorhus/KeyboardShortcuts) -- recommended SPM package for global hotkeys, Mac App Store compatible (HIGH confidence)
- [Paste app](https://pasteapp.io/) -- commercial competitor feature reference (MEDIUM confidence)
- [CleanClip](https://cleanclip.cc/) -- competitor with pinboard/favorites feature (MEDIUM confidence)
- [ClipPocket - BrightCoding](https://www.blog.brightcoding.dev/2026/02/08/clippocket-the-smart-clipboard-manager-macos-needs) -- Core Data + SQLite architecture for large history (MEDIUM confidence)
- [macOS defaults - screencapture location](https://macos-defaults.com/screenshots/location.html) -- `defaults read com.apple.screencapture location` documentation (HIGH confidence)
- [Apple Developer - NSEvent.addGlobalMonitorForEvents](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)) -- global event monitoring docs (HIGH confidence)
- [Apple Developer - CGEvent](https://developer.apple.com/forums/thread/659804) -- CGEvent paste simulation discussion (MEDIUM confidence)
- [macOS 26 built-in clipboard manager - 9to5Mac](https://9to5mac.com/2025/06/10/macos-26-spotlight-gets-actions-clipboard-manager-custom-shortcuts/) -- Apple adding clipboard history to Spotlight in macOS 26 (MEDIUM confidence, potential future competitive threat)

---
*Feature research for: macOS clipboard manager power user features (v1.2)*
*Researched: 2026-02-21*
