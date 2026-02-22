---
phase: quick
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - Copyhog/Copyhog/Store/ClipItemStore.swift
  - Copyhog/Copyhog/Views/ItemRow.swift
  - Copyhog/Copyhog/Views/PopoverContent.swift
autonomous: true
requirements: [QUICK-01]

must_haves:
  truths:
    - "User can unhide a sensitive item via context menu"
    - "Unhidden item shows its original content (text or image) instead of the HIDDEN card"
    - "Unhide option only appears on items that are currently sensitive"
  artifacts:
    - path: "Copyhog/Copyhog/Store/ClipItemStore.swift"
      provides: "unmarkSensitive(id:) method"
      contains: "func unmarkSensitive"
    - path: "Copyhog/Copyhog/Views/ItemRow.swift"
      provides: "Unhide context menu option for sensitive items"
      contains: "Unhide"
  key_links:
    - from: "Copyhog/Copyhog/Views/ItemRow.swift"
      to: "ClipItemStore.unmarkSensitive"
      via: "onUnmarkSensitive callback"
      pattern: "onUnmarkSensitive"
---

<objective>
Add an "Unhide" option to individual clipboard items that have been marked as sensitive, allowing users to reveal their content again.

Purpose: Currently items can be marked sensitive (hidden) but there is no way to reverse this. Users need the ability to unhide individual items.
Output: Context menu "Unhide" option on sensitive items that restores visibility.
</objective>

<execution_context>
@/Users/darrenbrelesky/.claude/get-shit-done/workflows/execute-plan.md
@/Users/darrenbrelesky/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@Copyhog/Copyhog/Store/ClipItemStore.swift
@Copyhog/Copyhog/Views/ItemRow.swift
@Copyhog/Copyhog/Views/PopoverContent.swift
@Copyhog/Copyhog/Models/ClipItem.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add unmarkSensitive method and wire Unhide context menu option</name>
  <files>
    Copyhog/Copyhog/Store/ClipItemStore.swift
    Copyhog/Copyhog/Views/ItemRow.swift
    Copyhog/Copyhog/Views/PopoverContent.swift
  </files>
  <action>
    1. In ClipItemStore.swift, add an `unmarkSensitive(id:)` method modeled after the existing `markSensitive(id:)`. It finds the item by UUID, creates a new ClipItem with `isSensitive: false`, replaces it in the array, and calls `save()`.

    2. In ItemRow.swift, add an `onUnmarkSensitive` optional closure property (matching the pattern of `onMarkSensitive`). In the `.contextMenu` block, add a condition: when `item.isSensitive`, show a Button labeled "Unhide" with systemImage "eye" that calls `onUnmarkSensitive?()`. This should appear alongside the existing Delete button. The existing "Mark as Sensitive" button already only shows when `!item.isSensitive`, so these are mutually exclusive.

    3. In PopoverContent.swift, in the `ItemRow(...)` initializer call inside the `ForEach`, add the `onUnmarkSensitive` parameter wired to `store.unmarkSensitive(id: item.id)`.
  </action>
  <verify>
    Build the project with Cmd+B in Xcode (or `xcodebuild build` from CLI). Verify:
    - No compilation errors
    - Right-click a sensitive item shows "Unhide" option
    - Right-click a non-sensitive item shows "Mark as Sensitive" (no "Unhide")
    - Clicking "Unhide" reveals the item content
  </verify>
  <done>
    Sensitive items display an "Unhide" context menu option. Tapping it sets isSensitive to false, revealing the original content. Non-sensitive items continue to show only "Mark as Sensitive" and "Delete".
  </done>
</task>

</tasks>

<verification>
- Build succeeds without errors
- Context menu on sensitive items shows "Unhide" + "Delete"
- Context menu on normal items shows "Mark as Sensitive" + "Delete"
- Unhiding a sensitive item reveals its text/image content in both ItemRow and PreviewPane
- The change persists after closing and reopening the popover (saved to items.json)
</verification>

<success_criteria>
Users can right-click any hidden/sensitive clipboard item and select "Unhide" to restore its visible content. The toggle is fully reversible: Mark as Sensitive hides, Unhide reveals.
</success_criteria>

<output>
After completion, create `.planning/quick/1-we-need-an-option-to-make-an-individual-/1-SUMMARY.md`
</output>
