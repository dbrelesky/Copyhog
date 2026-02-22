---
status: testing
phase: 07-favorites-history-scale
source: [07-01-SUMMARY.md, 07-02-SUMMARY.md]
started: 2026-02-22T05:10:00Z
updated: 2026-02-22T05:10:00Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

number: 1
name: Pin Item via Context Menu
expected: |
  Right-click any clipboard item in the history. The context menu shows "Pin" as the first option (with a pin icon). Clicking "Pin" moves the item to a dedicated "Pinned" section at the top of the list.
awaiting: user response

## Tests

### 1. Pin Item via Context Menu
expected: Right-click any clipboard item. Context menu shows "Pin" as first option with pin icon. Clicking "Pin" moves item to Pinned section at top.
result: [pending]

### 2. Unpin Item via Context Menu
expected: Right-click a pinned item. Context menu shows "Unpin" (with pin.slash icon). Clicking "Unpin" moves item back to the History section below.
result: [pending]

### 3. Pinned Section Header Visibility
expected: When at least one item is pinned, a "Pinned" section header (with pin.fill icon) appears at the top. A "History" section header (with clock icon) appears above unpinned items. When no items are pinned, the "Pinned" header is hidden entirely.
result: [pending]

### 4. Pin Icon Overlay on Pinned Items
expected: Pinned items display a small purple pin icon in the top-left corner of the card (circle background with ultraThinMaterial). The icon is NOT shown during multi-select mode.
result: [pending]

### 5. Pin/Unpin Animation
expected: When pinning or unpinning an item, it animates smoothly between the Pinned and History sections (not an instant jump).
result: [pending]

### 6. Pinned Items Survive Purge
expected: Set history limit to a small number (e.g., 20) in settings. Copy enough items to exceed the limit. Pinned items remain in the list while only unpinned items are removed when the limit is reached.
result: [pending]

### 7. History Limit Up to 500
expected: Open Settings. The history size picker shows options: 20, 50, 100, 200, 500.
result: [pending]

### 8. Scroll Performance at Scale
expected: With many items in history (100+), scrolling through both Pinned and History sections is smooth with no visible stutter or lag.
result: [pending]

### 9. Persistence Across Restart
expected: Pin some items, quit the app, relaunch. Pinned items are still pinned and appear in the Pinned section. No data loss.
result: [pending]

## Summary

total: 9
passed: 0
issues: 0
pending: 9
skipped: 0

## Gaps

[none yet]
