import SwiftUI

struct SettingsMenu: View {
    @Binding var showWipeConfirmation: Bool
    @State private var currentHotkeyDisplay: String = HotkeyConfig.shared.displayString

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        Menu {
            Text("Copyhog v\(appVersion)")

            Text("by Darren Brelesky")

            Divider()

            Menu("Hotkey: \(currentHotkeyDisplay)") {
                ForEach(Array(HotkeyConfig.presets.enumerated()), id: \.offset) { _, preset in
                    Button {
                        HotkeyConfig.shared.save(keyCode: preset.keyCode, modifiers: preset.modifiers)
                        currentHotkeyDisplay = preset.label
                    } label: {
                        if preset.keyCode == HotkeyConfig.shared.keyCode && preset.modifiers == HotkeyConfig.shared.modifierFlags {
                            Text("✓ \(preset.label)")
                        } else {
                            Text("  \(preset.label)")
                        }
                    }
                }
            }

            Divider()

            Button(role: .destructive) {
                showWipeConfirmation = true
            } label: {
                Label("Hog Wipe...", systemImage: "trash")
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Copyhog", systemImage: "xmark.circle")
            }
        } label: {
            Image(systemName: "gearshape")
        }
        .menuStyle(.borderlessButton)
    }
}
