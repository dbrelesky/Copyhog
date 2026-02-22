# Phase 6: Screenshot Auto-Detection - Research

**Researched:** 2026-02-21
**Domain:** macOS system defaults reading, sandbox entitlements, onboarding UX
**Confidence:** HIGH

## Summary

Phase 6 requires the app to auto-detect where macOS saves screenshots and pre-fill that location in the onboarding flow. macOS stores the screenshot save location in the `com.apple.screencapture` preference domain under the `location` key. When no custom location is set, the key is absent and macOS defaults to `~/Desktop`.

The existing codebase already has partial support: `OnboardingView.selectScreenshotFolder()` reads `UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")` to pre-select the NSOpenPanel directory. However, Copyhog is sandboxed (`com.apple.security.app-sandbox` is `true` in the entitlements), and sandboxed apps cannot read other apps' preference domains via `UserDefaults(suiteName:)`. This means the existing code likely returns `nil` in the sandbox, silently falling through.

**Primary recommendation:** Add the `com.apple.security.temporary-exception.shared-preference.read-only` entitlement for `com.apple.screencapture` to enable reading the screenshot location from within the sandbox. Extract the detection logic into a dedicated `ScreenshotLocationDetector` utility, update the onboarding view to display the detected path with a confirm/change flow instead of requiring manual selection from scratch.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SCRN-04 | App auto-detects macOS screenshot save location from system defaults on first launch | `UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")` with shared-preference temporary exception entitlement; falls back to `~/Desktop` when key is absent |
| SCRN-05 | Onboarding pre-fills detected screenshot folder, allowing user to confirm or change | Modify `OnboardingView` to show detected path as pre-filled label; user can accept or tap "Change..." to open NSOpenPanel |
| SCRN-06 | If no custom screenshot location is set, app defaults to ~/Desktop | When `location` key is nil/empty, use `FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")` |
</phase_requirements>

## Standard Stack

### Core

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| `UserDefaults(suiteName:)` | Foundation (built-in) | Read `com.apple.screencapture` preference domain | Apple's API for cross-domain UserDefaults access |
| `com.apple.security.temporary-exception.shared-preference.read-only` | App Sandbox entitlement | Permit sandboxed app to read system screenshot preferences | Apple-documented mechanism for reading another domain's preferences from sandbox |
| `NSOpenPanel` | AppKit (built-in) | User folder selection with pre-filled directory | Already used in existing OnboardingView |
| Security-scoped bookmarks | Foundation (built-in) | Persist folder access across restarts | Already implemented in BookmarkManager |

### Supporting

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `FileManager.default.homeDirectoryForCurrentUser` | Construct `~/Desktop` fallback path | When `location` key is nil or empty |
| `FileManager.default.fileExists(atPath:)` | Validate detected path exists | Before pre-filling onboarding |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Shared-preference entitlement | `Process("/usr/bin/defaults", ["read", ...])` | Subprocess execution may also be restricted in sandbox; less reliable; harder to test; Apple discourages shelling out for data that has an API |
| Shared-preference entitlement | Direct plist file read at `~/Library/Preferences/com.apple.screencapture.plist` | Requires `home-relative-path.read-only` temporary exception instead; Apple docs explicitly say NOT to use file-path exceptions for preferences -- use shared-preference exception instead |
| Modifying OnboardingView | New separate auto-detection screen | Over-engineering; the existing onboarding is simple and just needs the pre-fill + confirm UX added |

## Architecture Patterns

### Recommended Project Structure

No new directories needed. New code fits into existing structure:
```
Copyhog/
├── Services/
│   ├── ScreenshotWatcher.swift       # (existing)
│   ├── BookmarkManager.swift          # (existing)
│   └── ScreenshotLocationDetector.swift  # NEW — detection logic
├── Views/
│   └── OnboardingView.swift           # MODIFIED — pre-fill + confirm flow
└── Copyhog.entitlements               # MODIFIED — add shared-preference exception
```

### Pattern 1: Detection Utility with Fallback Chain

**What:** A small utility that reads the macOS screenshot location and returns a validated URL, with a well-defined fallback chain.
**When to use:** On first launch and when user taps "Setup Screenshot Folders..." in settings.
**Example:**

```swift
struct ScreenshotLocationDetector {
    /// Detects where macOS saves screenshots.
    /// Returns the custom location if set and valid, otherwise ~/Desktop.
    static func detect() -> URL {
        // 1. Try reading from com.apple.screencapture domain
        if let location = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
           !location.isEmpty {
            let expanded = (location as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // 2. Fallback to ~/Desktop
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
    }
}
```

### Pattern 2: Pre-fill + Confirm Onboarding Flow

**What:** Instead of requiring the user to manually browse and select their screenshot folder from scratch, show the detected path and let them confirm or change it.
**When to use:** Onboarding (first launch) and re-setup from settings menu.
**Example flow:**
1. Detect screenshot location via `ScreenshotLocationDetector.detect()`
2. Display: "We detected your screenshots save to: **[path]**"
3. Show two actions: "Use This Folder" (saves bookmark immediately) and "Choose Different..." (opens NSOpenPanel)
4. NSOpenPanel still opens with `directoryURL` pre-set to detected location

### Anti-Patterns to Avoid

- **Hardcoding ~/Desktop without checking system defaults:** The entire point of this phase is auto-detection. Always check `com.apple.screencapture` first.
- **Skipping path validation:** The user's configured screenshot location might not exist (e.g., external drive unmounted). Always validate with `fileExists(atPath:)`.
- **Writing to `com.apple.screencapture`:** Copyhog should never modify the system screenshot location. Read-only access only.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Reading macOS screenshot location | Plist parsing, shell subprocess | `UserDefaults(suiteName: "com.apple.screencapture")` with entitlement | Apple's standard API; plist format may change; shell execution adds complexity |
| Persisting folder access | Manual file path storage | Security-scoped bookmarks (already implemented in BookmarkManager) | Required for sandbox; already working |
| Tilde expansion in paths | Custom string replacement | `(path as NSString).expandingTildeInPath` | Handles edge cases; Foundation standard |

**Key insight:** The detection itself is trivial (one UserDefaults read + fallback). The real work is the entitlement configuration and the onboarding UX change from "select from scratch" to "confirm or change."

## Common Pitfalls

### Pitfall 1: Sandbox Blocks UserDefaults(suiteName:) for System Domains

**What goes wrong:** `UserDefaults(suiteName: "com.apple.screencapture")` returns `nil` for all keys because the sandbox prevents cross-domain reads.
**Why it happens:** App Sandbox restricts access to preference domains outside your app's container. The existing code in `OnboardingView.selectScreenshotFolder()` already attempts this read but likely fails silently in the sandbox.
**How to avoid:** Add `com.apple.security.temporary-exception.shared-preference.read-only` entitlement with `com.apple.screencapture` as the domain value.
**Warning signs:** Detection always returns `~/Desktop` even when user has a custom screenshot location.

### Pitfall 2: App Store Rejection for Temporary Exception Without Justification

**What goes wrong:** App Store review rejects the app because the temporary exception entitlement is not justified in App Store Connect.
**Why it happens:** Temporary exception entitlements require explanation in the "App Sandbox Entitlement Usage Information" section of App Store Connect.
**How to avoid:** In App Store Connect, explain: "Copyhog reads the com.apple.screencapture preference domain (read-only) to auto-detect the user's macOS screenshot save location during onboarding, so users don't have to manually locate their screenshot folder."
**Warning signs:** App Store rejection citing unauthorized entitlement usage.

### Pitfall 3: Detected Path No Longer Exists

**What goes wrong:** User configured a custom screenshot location (e.g., on an external drive) that is no longer available.
**Why it happens:** External drives get unmounted, folders get deleted.
**How to avoid:** Always validate with `FileManager.default.fileExists(atPath:)` before pre-filling. If invalid, fall back to `~/Desktop` and show that instead.
**Warning signs:** UI shows a path that doesn't resolve; NSOpenPanel opens to wrong location.

### Pitfall 4: Tilde Paths Not Expanded

**What goes wrong:** The `location` value from screencapture defaults may contain `~` (e.g., `~/Pictures/Screenshots`). Using it directly as a file path fails.
**Why it happens:** UserDefaults stores the string as-is; Foundation file APIs don't auto-expand `~`.
**How to avoid:** Always expand with `(location as NSString).expandingTildeInPath` before constructing a URL.
**Warning signs:** `fileExists(atPath:)` returns false for a path that visually looks correct.

### Pitfall 5: Location Key Absent vs. Empty String

**What goes wrong:** Treating an absent key and an empty string differently (or the same when they shouldn't be).
**Why it happens:** `UserDefaults.string(forKey:)` returns `nil` when the key doesn't exist, but the key could also be set to an empty string.
**How to avoid:** Check for both: `if let location = ..., !location.isEmpty`. Both cases should fall back to `~/Desktop`.
**Warning signs:** Empty string passed to path construction produces invalid URLs.

## Code Examples

### Reading the Screenshot Location (with sandbox entitlement)

```swift
// Source: Apple Developer Documentation + macos-defaults.com
// Requires entitlement: com.apple.security.temporary-exception.shared-preference.read-only
// with value array containing "com.apple.screencapture"

struct ScreenshotLocationDetector {
    static func detect() -> URL {
        if let location = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
           !location.isEmpty {
            let expanded = (location as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
    }
}
```

### Entitlement Configuration

```xml
<!-- Add to Copyhog.entitlements -->
<key>com.apple.security.temporary-exception.shared-preference.read-only</key>
<array>
    <string>com.apple.screencapture</string>
</array>
```

### Modified Onboarding Screenshot Folder Row (conceptual)

```swift
// Instead of immediately opening NSOpenPanel, show detected path first
@State private var detectedScreenshotURL: URL = ScreenshotLocationDetector.detect()

// In the folder row for step 1:
VStack(alignment: .leading, spacing: 2) {
    Text("Screenshot Folder").font(.headline)
    Text(detectedScreenshotURL.path).font(.caption).foregroundStyle(.secondary)
}

HStack {
    Button("Use This") {
        bookmarkManager.saveBookmark(url: detectedScreenshotURL, key: BookmarkManager.screenshotSourceKey)
        screenshotGranted = true
    }
    Button("Change...") {
        selectScreenshotFolder()  // Opens NSOpenPanel with directoryURL pre-set
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `defaults write com.apple.screencapture location` + `killall SystemUIServer` | Screenshot.app (Cmd+Shift+5) > Options > Save to | macOS Mojave (2018) | GUI method is now standard; Terminal method still works and writes to same plist |
| No sandbox restrictions on UserDefaults | Sandbox blocks cross-domain UserDefaults reads | macOS 10.7+ (App Sandbox) | Must use temporary exception entitlement for read access |

**Deprecated/outdated:**
- The `killall SystemUIServer` requirement after changing screenshot location: still documented but may not be necessary on newer macOS versions where Screenshot.app manages its own preferences
- STATE.md claims "App Sandbox disabled in entitlements" but the actual entitlements file shows sandbox IS enabled. This is a stale note that should be corrected.

## Open Questions

1. **Will App Store accept the shared-preference temporary exception?**
   - What we know: Apple documents this entitlement specifically for this use case. The justification is clear (reading screenshot save location for user convenience).
   - What's unclear: Apple's review process is opaque; some temporary exceptions get rejected.
   - Recommendation: Proceed with the entitlement. If rejected, fall back to always defaulting to `~/Desktop` with manual override. The entitlement is lightweight and well-justified -- detection is purely a UX convenience, not core functionality.

2. **Does `UserDefaults(suiteName:)` return the `location` key immediately after adding the entitlement, or is there caching?**
   - What we know: UserDefaults caches reads; the entitlement grants access at the OS level.
   - What's unclear: Whether the app needs to be relaunched after entitlement is added during development.
   - Recommendation: Test during development. In production the entitlement is present from first launch.

3. **What about localized screenshot file names?**
   - What we know: This phase is about FOLDER detection, not file detection. ScreenshotWatcher already handles file name patterns.
   - What's unclear: Nothing -- this is not relevant to Phase 6.
   - Recommendation: No action needed.

## Sources

### Primary (HIGH confidence)
- [Apple Developer Documentation: App Sandbox Temporary Exception Entitlements](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html) -- Shared preference read-only exception entitlement key and usage
- [macos-defaults.com: Screenshots > Set location](https://macos-defaults.com/screenshots/location.html) -- Domain `com.apple.screencapture`, key `location`, default is `~/Desktop`, supported Mojave through Sonoma+
- Existing codebase: `OnboardingView.swift` lines 131-137 already read `com.apple.screencapture` `location` key
- Existing codebase: `Copyhog.entitlements` confirms sandbox IS enabled (`com.apple.security.app-sandbox: true`)
- Local machine verification: `defaults read com.apple.screencapture` shows no `location` key when default (Desktop) is used

### Secondary (MEDIUM confidence)
- [Apple Developer Forums: Accessing UserDefaults when sandboxed](https://developer.apple.com/forums/thread/659448) -- Confirms sandboxed apps cannot read other domains without entitlements
- [Apple Developer Forums: macOS & NSUserDefaults](https://developer.apple.com/forums/thread/116297) -- Sandbox restricts cross-domain UserDefaults access
- [Macworld: How to change where screenshots are saved](https://www.macworld.com/article/673251/how-to-change-where-screenshots-are-saved-on-a-mac.html) -- Confirms `com.apple.screencapture` domain and `location` key

### Tertiary (LOW confidence)
- General web search results about sandbox subprocess execution -- inconclusive on whether `Process("/usr/bin/defaults")` works in sandbox

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- UserDefaults API is well-documented; entitlement key is in Apple's official archive docs; verified on local machine
- Architecture: HIGH -- Simple detection utility + onboarding modification; follows existing codebase patterns exactly
- Pitfalls: HIGH -- Sandbox restriction is the main risk and is well-documented; entitlement solution is Apple's prescribed approach

**Research date:** 2026-02-21
**Valid until:** 2026-03-21 (stable -- macOS defaults API has not changed in years)
