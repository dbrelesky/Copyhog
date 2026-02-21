# Copyhog

## What This Is

A native macOS menu bar app that automatically captures clipboard items (text and images) and screenshots into a browsable history with instant re-paste. Built with Swift + SwiftUI, it runs silently in the background and is accessible via menu bar icon or global hotkey.

## Core Value

Every screenshot and clipboard copy is captured and instantly accessible — no hunting, no lost items, no broken workflow.

## Requirements

### Validated

- ✓ Automatically capture clipboard items (text + images) and screenshots into persistent history — v1.0
- ✓ Run as macOS menu bar app with split-view popover (~360x480px): preview top, list bottom — v1.0
- ✓ Observer mode — watch system clipboard + screenshot directory, don't replace native shortcuts — v1.0
- ✓ When a screenshot is detected, automatically copy it to the system clipboard — v1.0
- ✓ Move/save all detected screenshots to ~/Documents/Screenies/ — v1.0
- ✓ Show browsable list of recent items with visual previews (thumbnails for images, text snippets for text) — v1.0
- ✓ Single-select: clicking an item copies it to system clipboard for pasting — v1.0
- ✓ Multi-select images: write multiple images as file URL references to pasteboard for batch paste — v1.0
- ✓ Drag-and-drop: drag selected items from Copyhog into target apps — v1.0
- ✓ Retain last 20 items, auto-purge oldest when limit exceeded — v1.0

### Active

- [ ] Fix global hotkey (Shift+Up Arrow) to toggle popover open/close from any app
- [ ] Delete individual item from clipboard history
- [ ] Master wipe ("Hog Wipe") to clear all saved items at once

### Out of Scope

- Copyhog-initiated screenshot capture (own capture shortcut) — deferred, observer-only for v1
- Rich text / file clipboard types — text + images only for v1
- Search/filter within history — only 20 items, browse is sufficient
- Clipboard sync across devices — local-only for v1
- Visual distinction between screenshots and regular copied images — not needed per user preference

## Context

**Problem:** macOS screenshot workflow is broken. The thumbnail disappears after ~5 seconds, files save with arbitrary names like `Screenshot 2026-02-20 at 3.42.15 PM.png`, and getting a screenshot back into another app requires multiple steps (find file, open, copy, switch back, paste). The system clipboard only holds one item — previous copies are lost forever.

**Solution shaped as:** "Shape A: Menu Bar Observer with Local Image Store" — a background observer that polls the clipboard and watches the screenshot directory, captures items into a local store, and presents them in a popover UI for rapid re-paste.

**Architecture (from breadboard):**
- P1: Menu Bar — persistent hedgehog silhouette icon
- P2: Popover (Split View) — preview pane top, item list bottom
- P3: Background Services — ClipboardObserver (polls NSPasteboard), ScreenshotWatcher (FSEvents), ScreenshotProcessor, ClipItemStore, ImageStore

**Multi-select mechanism:** Writes multiple images as file URL references to NSPasteboard (multiple NSPasteboardItem objects). Apps that accept file drops (Slack, Mail, Figma) receive all selected images. Text items concatenate with newlines.

**Full shaping doc:** `copyhog-shaping.md` (requirements, shape, fit check, breadboard with full wiring)

## Constraints

- **Tech stack**: Swift + SwiftUI — native macOS, MenuBarExtra API, minimum footprint
- **Platform**: macOS only (menu bar app pattern)
- **Storage**: Last 20 items, auto-purge oldest. Images stored in ~/Library/Application Support/Copyhog/
- **Screenshots**: All screenshots moved to ~/Documents/Screenies/ (not left on Desktop)
- **Hotkey**: Shift+Up Arrow registered via NSEvent.addGlobalMonitorForEvents
- **Clipboard**: Observer mode only — poll NSPasteboard.general.changeCount every 0.5s

## Current Milestone: v1.1 Polish & Control

**Goal:** Give the user full control over their clipboard history — fix the broken hotkey, let them delete individual items, and wipe everything clean.

**Target features:**
- Fix global hotkey toggle (Shift+Up Arrow)
- Delete individual clipboard items
- Master "Hog Wipe" to clear all items

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Swift + SwiftUI over Electron/Tauri | Smallest memory footprint, native macOS feel, MenuBarExtra purpose-built for this | — Pending |
| Observer mode over intercept mode | Non-invasive, user keeps native Cmd+Shift+3/4/5 shortcuts | — Pending |
| File URL references for multi-image paste | NSPasteboard can't hold multiple independent images; file URLs work with apps that accept file drops | — Pending |
| 20 item limit with auto-purge | Keeps storage minimal, browse is fast, no need for search | — Pending |
| Popover over floating panel | Standard macOS pattern for menu bar utilities (1Password, Bartender), predictable appear/disappear | — Pending |
| Split-view layout (preview top, list bottom) | 64px thumbnails aren't enough to distinguish screenshots; preview is the key differentiator | — Pending |

---
*Last updated: 2026-02-21 after milestone v1.1 started*
