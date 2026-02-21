import AppKit

struct HotkeyPreset: Sendable {
    let label: String
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
}

@MainActor
final class HotkeyConfig: Sendable {
    static let shared = HotkeyConfig()

    static let configChangedNotification = Notification.Name("HotkeyConfigChanged")

    static let presets: [HotkeyPreset] = [
        HotkeyPreset(label: "Shift+Ctrl+C", keyCode: 8, modifiers: [.shift, .control]),
        HotkeyPreset(label: "Shift+Ctrl+V", keyCode: 9, modifiers: [.shift, .control]),
        HotkeyPreset(label: "Shift+Ctrl+H", keyCode: 4, modifiers: [.shift, .control]),
        HotkeyPreset(label: "Cmd+Shift+V", keyCode: 9, modifiers: [.command, .shift]),
    ]

    private let keyCodeKey = "hotkeyKeyCode"
    private let modifiersKey = "hotkeyModifiers"

    var keyCode: UInt16 {
        let stored = UserDefaults.standard.integer(forKey: keyCodeKey)
        if stored == 0 && UserDefaults.standard.object(forKey: keyCodeKey) == nil {
            return 8 // Default: 'C'
        }
        return UInt16(stored)
    }

    var modifierFlags: NSEvent.ModifierFlags {
        if UserDefaults.standard.object(forKey: modifiersKey) == nil {
            return [.shift, .control] // Default
        }
        let raw = UInt(UserDefaults.standard.integer(forKey: modifiersKey))
        return NSEvent.ModifierFlags(rawValue: raw)
    }

    var displayString: String {
        for preset in Self.presets {
            if preset.keyCode == keyCode && preset.modifiers == modifierFlags {
                return preset.label
            }
        }
        return "Custom"
    }

    func save(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        UserDefaults.standard.set(Int(keyCode), forKey: keyCodeKey)
        UserDefaults.standard.set(Int(modifiers.rawValue), forKey: modifiersKey)
        NotificationCenter.default.post(name: Self.configChangedNotification, object: nil)
    }
}
