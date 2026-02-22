import SwiftUI

struct PreviewPane: View {
    let item: ClipItem?
    let imageStore: ImageStore

    var body: some View {
        Group {
            if let item {
                if item.isSensitive {
                    VStack(spacing: 10) {
                        ZStack {
                            if let bundleID = item.sourceAppBundleID,
                               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 48, height: 48)
                            } else {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.secondary)
                            }

                            // Lock badge
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(4)
                                        .background(Color.secondary, in: Circle())
                                }
                            }
                            .frame(width: 52, height: 52)
                        }

                        if let appName = item.sourceAppName {
                            Text("Copied from \(appName)")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        } else {
                            Text("Sensitive Content")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }

                        Text("HIDDEN")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.12))
                            )

                        Text("Content is protected — click card to copy")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ZStack(alignment: .bottomLeading) {
                        switch item.type {
                        case .image:
                            if let filePath = item.filePath,
                               let nsImage = imageStore.loadImage(relativePath: filePath) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        case .text:
                            ScrollView {
                                Text(item.content ?? "")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // Type label with optional source app icon
                        HStack(spacing: 4) {
                            if item.sourceAppBundleID == "com.apple.screencaptureui" {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            } else if let bundleID = item.sourceAppBundleID,
                               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 14, height: 14)
                            }
                            Text(itemTypeLabel(item))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                    }
                }
            } else {
                Image(systemName: "clipboard")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }

    private func itemTypeLabel(_ item: ClipItem) -> String {
        if item.sourceAppBundleID == "com.apple.screencaptureui" {
            return "Screenshot"
        }
        return item.type == .text ? "Text" : "Image"
    }
}
