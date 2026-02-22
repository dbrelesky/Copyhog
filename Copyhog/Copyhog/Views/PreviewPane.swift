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
                                    .foregroundStyle(Color(red: 0.7, green: 0.4, blue: 0.85))
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
                                        .background(Color(red: 0.7, green: 0.4, blue: 0.85), in: Circle())
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
                            .foregroundStyle(Color(red: 0.7, green: 0.4, blue: 0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.7, green: 0.4, blue: 0.85).opacity(0.15))
                            )

                        Text("Content is protected — click card to copy")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
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
                }
            } else {
                Image(systemName: "clipboard")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color(red: 0.4, green: 0.2, blue: 0.5).opacity(0.1)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }
}
