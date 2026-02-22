import SwiftUI
import AppKit

struct OnboardingView: View {
    let bookmarkManager: BookmarkManager
    var onComplete: () -> Void
    var onSkip: () -> Void

    @State private var screenshotGranted = false
    @State private var screeniesGranted = false

    private let accentPurple = Color(red: 0.7, green: 0.4, blue: 0.85)

    var body: some View {
        VStack(spacing: 20) {
            Image("MenuBarIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
                .opacity(0.6)

            Text("Welcome to Copyhog")
                .font(.title.bold())

            Text("To capture screenshots automatically, grant access to two folders.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                folderRow(
                    step: 1,
                    title: "Screenshot Folder",
                    description: "Where macOS saves screenshots",
                    granted: screenshotGranted,
                    disabled: false,
                    action: selectScreenshotFolder
                )

                folderRow(
                    step: 2,
                    title: "Screenies Folder",
                    description: "Where Copyhog moves them",
                    granted: screeniesGranted,
                    disabled: !screenshotGranted,
                    action: selectScreeniesFolder
                )
            }

            Spacer()

            HStack {
                Button("Skip for Now") {
                    onSkip()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button("Start Capturing Screenshots") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!(screenshotGranted && screeniesGranted))
            }
        }
        .padding(24)
        .frame(width: 400, height: 320)
        .background {
            Color(red: 0.35, green: 0.15, blue: 0.45).opacity(0.12)
        }
        .background(.ultraThinMaterial)
        .tint(accentPurple)
    }

    // MARK: - Folder Row

    @ViewBuilder
    private func folderRow(
        step: Int,
        title: String,
        description: String,
        granted: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(accentPurple)
                    .font(.title2)
                    .frame(width: 28)
            } else {
                Text("\(step)")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(accentPurple.opacity(0.4)))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Button("Select...") { action() }
                .disabled(disabled)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.4, green: 0.2, blue: 0.5).opacity(0.1))
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Folder Pickers

    private func selectScreenshotFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your screenshot folder"

        // Pre-select macOS screenshot location if available
        if let location = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
           !location.isEmpty {
            let url = URL(fileURLWithPath: (location as NSString).expandingTildeInPath)
            if FileManager.default.fileExists(atPath: url.path) {
                panel.directoryURL = url
            }
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }
        bookmarkManager.saveBookmark(url: url, key: BookmarkManager.screenshotSourceKey)
        screenshotGranted = true
    }

    private func selectScreeniesFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select or create your Screenies folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        bookmarkManager.saveBookmark(url: url, key: BookmarkManager.screeniesDestKey)
        screeniesGranted = true
    }
}
