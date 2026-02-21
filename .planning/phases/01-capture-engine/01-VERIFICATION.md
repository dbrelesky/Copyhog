---
phase: 01-capture-engine
verified: 2026-02-21T00:00:00Z
status: gaps_found
score: 4/5 must-haves verified
re_verification: false
gaps:
  - truth: "Pressing Shift+Up Arrow toggles the popover open and closed from any app"
    status: failed
    reason: "Event monitors are registered and togglePopover() is implemented, but it relies on a private KVC key ('statusItem') to reach NSStatusItem button and call performClick(nil). This approach is fragile and correctness at runtime is unconfirmed — the known-deferred issue from plan 01-01."
    artifacts:
      - path: "Copyhog/Copyhog/CopyhogApp.swift"
        issue: "togglePopover() uses NSApp.windows.compactMap({ $0.value(forKey: 'statusItem') as? NSStatusItem }) — private KVC key, may silently return nil and do nothing"
    missing:
      - "Verified, reliable toggle mechanism — either confirm the KVC lookup works at runtime or replace with a direct NSStatusItem reference held by AppDelegate"
