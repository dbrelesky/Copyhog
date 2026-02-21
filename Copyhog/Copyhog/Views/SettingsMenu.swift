import SwiftUI

struct SettingsMenu: View {
    @Binding var showWipeConfirmation: Bool

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        Menu {
            Text("Copyhog v\(appVersion)")

            Text("by Darren Brelesky")

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
