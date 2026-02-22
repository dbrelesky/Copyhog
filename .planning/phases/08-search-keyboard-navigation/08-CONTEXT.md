# Phase 8: Search + Keyboard Navigation - Context

**Gathered:** 2026-02-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can find clipboard history items by typing a search query, and navigate the entire popover using only the keyboard. Covers search field, real-time filtering, arrow key navigation, Enter to copy, and Escape to dismiss. Advanced search features (fuzzy matching, regex, search history) are out of scope.

</domain>

<decisions>
## Implementation Decisions

### Search field behavior
- Search field requires explicit focus — no typeahead from anywhere in the popover
- On popover open, focus lands on the first list item (not the search field) — optimized for quick arrow-key + Enter workflows
- Placeholder text: "Search history..."
- Tab moves focus between search field and list; Shift+Tab goes back

### Filtering & matching
- Search filters pinned and regular items equally — pinned items are hidden if they don't match the query
- Matched text should be visually highlighted (bold or color) in the filtered results
- Clearing the search field restores the full list with pinned items back at the top

### Keyboard flow
- Arrow keys stop at edges — no wrap-around (down at last item does nothing, up at first does nothing)
- Tab navigates between search field and list; Shift+Tab reverses direction
- Enter on a selected item copies it to clipboard
- Escape clears search text first if present, then dismisses popover on second press (per success criteria)

### Claude's Discretion
- Search field visual treatment (search icon, clear button, styling)
- What gets searched — text content only vs also including source app name
- No-results empty state messaging and design
- Behavior when typing while list is focused (redirect to search vs ignore)
- Preview pane update timing when arrowing through items (immediate vs debounced)
- Search debounce timing for real-time filtering

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 08-search-keyboard-navigation*
*Context gathered: 2026-02-22*
