import SwiftUI

struct ItemRow: View {
    let item: ClipItem
    let imageStore: ImageStore
    @Binding var hoveredItemID: UUID?
    @Binding var selectedItems: Set<UUID>
    let clipboardObserver: ClipboardObserver?
    var isSelected: Bool = false
    var searchQuery: String = ""
    var copiedItemID: UUID? = nil
    var gridIndex: Int? = nil
    var onCopy: (() -> Void)?
    var onCommandSelectionChanged: (() -> Void)? = nil
    var onDelete: (() -> Void)?
    var onMarkSensitive: (() -> Void)?
    var onUnmarkSensitive: (() -> Void)?
    @State private var showCopyConfirmation = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        cardContent
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(item.isSensitive
                        ? Color.primary.opacity(0.06)
                        : Theme.cardBackground(scheme: colorScheme))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected
                            ? Theme.accent.opacity(0.6)
                            : item.isSensitive
                                ? Color.primary.opacity(0.12)
                                : cardStrokeColor,
                        lineWidth: isSelected ? 2 : (item.isSensitive ? 1.5 : 1)
                    )
            )
            .shadow(color: Color.black.opacity((hoveredItemID == item.id || isSelected) ? 0.08 : 0), radius: 8, y: 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hoveredItemID)
            .animation(.easeInOut(duration: 0.2), value: showCopyConfirmation)
            .contentShape(Rectangle())
            .draggable(item) {
                Label(
                    item.type == .text ? "Text" : "Image",
                    systemImage: item.type == .text ? "doc.text" : "photo"
                )
            }
            .simultaneousGesture(TapGesture().onEnded {
                let commandHeld = NSEvent.modifierFlags.contains(.command)
                if commandHeld {
                    if selectedItems.contains(item.id) {
                        selectedItems.remove(item.id)
                    } else {
                        selectedItems.insert(item.id)
                    }
                    onCommandSelectionChanged?()
                } else if let observer = clipboardObserver {
                    selectedItems.removeAll()
                    PasteboardWriter.write(item, imageStore: imageStore, clipboardObserver: observer)
                    onCopy?()
                    if AutoPasteService.isEnabled {
                        AutoPasteService.pasteAfterDismiss()
                    } else {
                        showCopyConfirmation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            showCopyConfirmation = false
                        }
                    }
                }
            })
            .onHover { hovering in
                hoveredItemID = hovering ? item.id : nil
            }
            .onChange(of: copiedItemID) { _, newValue in
                if newValue == item.id {
                    showCopyConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        showCopyConfirmation = false
                    }
                }
            }
            .contextMenu {
                if item.isSensitive {
                    Button {
                        onUnmarkSensitive?()
                    } label: {
                        Label("Unhide", systemImage: "eye")
                    }
                } else {
                    Button {
                        onMarkSensitive?()
                    } label: {
                        Label("Mark as Sensitive", systemImage: "lock.shield")
                    }
                }

                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    private var cardStrokeColor: Color {
        if item.type == .image {
            return Color.blue.opacity(hoveredItemID == item.id ? 0.4 : 0.3)
        } else {
            return Color.gray.opacity(hoveredItemID == item.id ? 0.4 : 0.3)
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        ZStack {
            // Main card content
            if item.type == .image {
                imageCardContent
            } else {
                textCardContent
            }

            // Bottom row — source app left, timestamp right
            if !item.isSensitive {
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        // Source app + type label — bottom-left
                        HStack(spacing: 3) {
                            if item.sourceAppBundleID == "com.apple.screencaptureui" {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.secondary)
                            } else if let bundleID = item.sourceAppBundleID,
                               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 12, height: 12)
                            }
                            Text(itemTypeLabel)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))

                        Spacer()

                        // Simplified timestamp — bottom-right
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            Text(simplifiedTimestamp(from: item.timestamp, now: context.date))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                .padding(5)
            }

            // ⌘ shortcut badge — top-right
            if let idx = gridIndex, idx < 9 {
                VStack {
                    HStack {
                        Spacer()
                        Text("⌘\(idx + 1)")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    }
                    Spacer()
                }
                .padding(5)
            }

            // Command-selected indicator — top-left
            if selectedItems.contains(item.id) {
                VStack {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.body)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 20, height: 20)
                            )
                        Spacer()
                    }
                    Spacer()
                }
                .padding(5)
            }

            // Copy confirmation checkmark — centered
            if showCopyConfirmation {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .green.opacity(0.85))
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 36, height: 36)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 4, y: 1)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var sensitiveCardContent: some View {
        ZStack {
            Color.primary.opacity(0.06)

            VStack(spacing: 4) {
                ZStack {
                    if let bundleID = item.sourceAppBundleID,
                       let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }

                    // Lock badge on app icon
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(3)
                                .background(Color.secondary, in: Circle())
                        }
                    }
                    .frame(width: 36, height: 36)
                }

                if let appName = item.sourceAppName {
                    Text(appName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Text("HIDDEN")
                    .font(.system(size: 7, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var imageCardContent: some View {
        if item.isSensitive {
            sensitiveCardContent
        } else if let thumbPath = item.thumbnailPath,
           let nsImage = imageStore.loadImage(relativePath: thumbPath) {
            GeometryReader { geo in
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
        } else {
            Image(systemName: "photo")
                .font(.title)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var textCardContent: some View {
        VStack(spacing: 0) {
            if item.isSensitive {
                sensitiveCardContent
            } else if !searchQuery.isEmpty {
                Text(highlightedText(content: item.content ?? "", query: searchQuery))
                    .font(.system(size: 10))
                    .foregroundStyle(.primary)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
            } else {
                Text(item.content ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
            }
        }
    }

    private var itemTypeLabel: String {
        if item.sourceAppBundleID == "com.apple.screencaptureui" {
            return "Screenshot"
        }
        return item.type == .text ? "Text" : "Image"
    }

    private func simplifiedTimestamp(from date: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 {
            return "just now"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return minutes == 1 ? "1 min ago" : "\(minutes) mins ago"
        }
        let hours = minutes / 60
        if hours < 24 {
            return hours == 1 ? "1 hr ago" : "\(hours) hrs ago"
        }
        let days = hours / 24
        return days == 1 ? "1 day ago" : "\(days) days ago"
    }

    private func highlightedText(content: String, query: String) -> AttributedString {
        var attributed = AttributedString(content)
        guard !query.isEmpty else { return attributed }

        let contentLower = content.lowercased()
        let queryLower = query.lowercased()

        var searchStart = contentLower.startIndex
        while searchStart < contentLower.endIndex {
            guard let range = contentLower.range(of: queryLower, range: searchStart..<contentLower.endIndex) else {
                break
            }
            // Convert String.Index range to AttributedString.Index range
            if let attrStart = AttributedString.Index(range.lowerBound, within: attributed),
               let attrEnd = AttributedString.Index(range.upperBound, within: attributed) {
                attributed[attrStart..<attrEnd].foregroundColor = Theme.accent
                attributed[attrStart..<attrEnd].font = .system(size: 10, weight: .bold)
            }
            searchStart = range.upperBound
        }

        return attributed
    }
}
