import Foundation

/// Detects strings that look like passwords or secrets based on entropy and character patterns.
/// No app detection needed — works purely on the content itself.
enum PasswordDetector {

    /// Returns true if the string looks like a password, API key, or secret token.
    static func looksLikePassword(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Must be a single line (passwords are never multi-line)
        guard !trimmed.contains("\n") else { return false }

        let length = trimmed.count

        // Too short or too long to be a password
        // Passwords: 6-128 chars. API keys/tokens can be longer.
        guard length >= 8 && length <= 128 else { return false }

        // Must not contain spaces (passwords almost never have spaces;
        // this filters out normal short sentences)
        guard !trimmed.contains(" ") else { return false }

        // File paths — starts with / or ~/ or contains multiple /
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~/") {
            return false
        }

        // Check character class diversity
        let hasUpper = trimmed.contains(where: { $0.isUppercase })
        let hasLower = trimmed.contains(where: { $0.isLowercase })
        let hasDigit = trimmed.contains(where: { $0.isNumber })
        let hasSpecial = trimmed.contains(where: { !$0.isLetter && !$0.isNumber })

        let classCount = [hasUpper, hasLower, hasDigit, hasSpecial].filter { $0 }.count

        // High entropy check — Shannon entropy per character
        let entropy = shannonEntropy(trimmed)

        // Strong password indicators:
        // 1. Has 3+ character classes AND high entropy
        if classCount >= 3 && entropy >= 3.0 {
            return true
        }

        // 2. Has all 4 character classes (almost certainly a password)
        if classCount == 4 {
            return true
        }

        // 3. Very high entropy alone (random strings like API keys: "a8f3b2c1d9e4...")
        if entropy >= 3.8 && length >= 16 {
            return true
        }

        // 4. Looks like a hex token or base64 key (common API key patterns)
        if looksLikeToken(trimmed) {
            return true
        }

        return false
    }

    /// Shannon entropy in bits per character.
    /// Random passwords have ~4+ bits/char. English text has ~1-2 bits/char.
    static func shannonEntropy(_ string: String) -> Double {
        let length = Double(string.count)
        guard length > 0 else { return 0 }

        var freq: [Character: Int] = [:]
        for char in string {
            freq[char, default: 0] += 1
        }

        var entropy = 0.0
        for count in freq.values {
            let p = Double(count) / length
            if p > 0 {
                entropy -= p * log2(p)
            }
        }
        return entropy
    }

    /// Detects common token/key patterns: hex strings, base64, UUIDs, JWT-like.
    private static func looksLikeToken(_ text: String) -> Bool {
        // UUID pattern
        let uuidPattern = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/
        if text.wholeMatch(of: uuidPattern) != nil { return false } // UUIDs are not passwords

        // Long hex string (32+ chars, like API keys)
        let hexPattern = /^[0-9a-fA-F]{32,}$/
        if text.wholeMatch(of: hexPattern) != nil { return true }

        // Base64 with mixed case and/or trailing = (common for tokens)
        let base64Pattern = /^[A-Za-z0-9+\/]{20,}={0,3}$/
        if text.wholeMatch(of: base64Pattern) != nil && shannonEntropy(text) >= 3.5 {
            return true
        }

        // JWT-like (three dot-separated base64 segments)
        let parts = text.split(separator: ".")
        if parts.count == 3 && parts.allSatisfy({ $0.count >= 10 }) {
            return true
        }

        return false
    }
}
