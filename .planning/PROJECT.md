# Copyhog

## What This Is

A native macOS menu bar app that automatically captures clipboard items (text and images) and screenshots into a browsable history with instant re-paste. Features a liquid glass UI with translucent materials, configurable history (up to 500 items), and App Store-ready privacy compliance. Built with Swift + SwiftUI.

## Core Value

Every screenshot and clipboard copy is captured and instantly accessible — no hunting, no lost items, no broken workflow.

## Requirements

### Validated

- ✓ Automatically capture clipboard items (text + images) and screenshots into persistent history — v1.0
- ✓ Run as macOS menu bar app with split-view popover: preview top, list bottom — v1.0
- ✓ Observer mode — watch system clipboard + screenshot directory, don't replace native shortcuts — v1.0
- ✓ Screenshots auto-copied to system clipboard and moved to ~/Documents/Screenies/ — v1.0
- ✓ Browsable list with visual previews (thumbnails for images, text snippets) — v1.0
- ✓ Single-click copy, multi-select batch paste, drag-and-drop — v1.0
- ✓ Delete individual items and bulk wipe ("Hog Wipe") — v1.1
- ✓ Settings menu with version, attribution, and relocated destructive actions — v1.1
- ✓ Liquid glass UI — translucent materials, elevated preview, floating toolbar — v1.1
- ✓ App Sandbox with privacy strings and sensitive app exclusion — v1.1
- ✓ Privacy manifest, launch-at-login toggle, configurable history size — v1.1
- ✓ Auto-detect macOS screenshot save location — v1.2
- ✓ 500-item history with debounced persistence and thumbnail caching — v1.2

### Active

- [ ] Global keyboard shortcut to summon clipboard history from any app
- [ ] Search/filter clipboard history by text content
- [ ] Keyboard navigation through items with Enter to paste
- [ ] Paste-on-select: Enter pastes directly into previously active app

### Out of Scope

- Copyhog-initiated screenshot capture (own capture shortcut) — deferred, observer-only
- Rich text / file clipboard types — text + images only
- Clipboard sync across devices — local-only
- Visual distinction between screenshots and regular copied images — not needed per user preference
- Snippet/template system with placeholders — beyond clipboard history scope
- iCloud sync — local-only for now
- Fuzzy search — exact text match covers 90% of use cases
- Pin/favorites system — removed, feature wasn't successful

## Context

**Shipped:** v1.0 MVP (2026-02-21), v1.1 Polish & Control (2026-02-22)
**Current:** v1.2 Power User Essentials — Phases 6-7 complete, Phases 8-9 remaining
**Codebase:** ~3800 LOC Swift/SwiftUI, 50+ files
**Tech stack:** Swift + SwiftUI, MenuBarExtra, NSPasteboard polling, FSEvents, App Sandbox

**Architecture:**
- P1: Menu Bar — persistent hedgehog silhouette icon
- P2: Popover (Split View) — glass preview pane top, item list bottom
- P3: Background Services — ClipboardObserver, ScreenshotWatcher, ScreenshotLocationDetector, ClipItemStore, ImageStore, ExclusionManager

**Multi-select mechanism:** Writes multiple images as file URL references to NSPasteboard. Apps that accept file drops (Slack, Mail, Figma) receive all selected images.

**Full shaping doc:** `copyhog-shaping.md`

## Current Milestone: v1.2 Power User Essentials

**Goal:** Make Copyhog a keyboard-driven power tool — instant access from anywhere, searchable history, and zero-config screenshot detection.

**Remaining:**
- Phase 8: Search + Keyboard Navigation
- Phase 9: Global Hotkey + Paste-on-Select

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Swift + SwiftUI over Electron/Tauri | Smallest memory footprint, native macOS feel, MenuBarExtra purpose-built for this | ✓ Good |
| Observer mode over intercept mode | Non-invasive, user keeps native Cmd+Shift+3/4/5 shortcuts | ✓ Good |
| File URL references for multi-image paste | NSPasteboard can't hold multiple independent images; file URLs work with apps that accept file drops | ✓ Good |
| Popover over floating panel | Standard macOS pattern for menu bar utilities, predictable appear/disappear | ✓ Good |
| Split-view layout (preview top, list bottom) | 64px thumbnails aren't enough to distinguish screenshots; preview is the key differentiator | ✓ Good |
| ultraThinMaterial / regularMaterial hierarchy | Creates visual depth without Divider() lines; warm orange tint adds personality | ✓ Good — v1.1 |
| App Sandbox with temporary exceptions | Required for App Store; shared-preference exception enables screenshot location detection | ✓ Good — v1.1 |
| 500-item limit with debounced saves | NSCache for thumbnails + 500ms debounced JSON writes keeps UI smooth at scale | ✓ Good — v1.2 |
| Pin/favorites removed | Feature wasn't successful; simplified to flat history list | Removed — v1.2 |

---
*Last updated: 2026-02-22 after v1.1 milestone*
