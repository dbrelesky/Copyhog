import SwiftUI

struct ItemRow: View {
    let item: ClipItem
    let imageStore: ImageStore
    @Binding var hoveredItemID: UUID?
    let isMultiSelectActive: Bool
    @Binding var selectedItems: Set<UUID>
    let clipboardObserver: ClipboardObserver?
    var isSelected: Bool = false
    var searchQuery: String = ""
    var onTogglePin: (() -> Void)?
    var onDelete: (() -> Void)?
    var onMarkSensitive: (() -> Void)?
    var onUnmarkSensitive: (() -> Void)?
    @State private var showCopyConfirmation = false

    var body: some View {
        cardContent
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.4, green: 0.2, blue: 0.5).opacity(item.isSensitive ? 0.18 : 0.12))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected
                            ? Color(red: 0.7, green: 0.4, blue: 0.85).opacity(0.8)
                            : item.isSensitive
                                ? Color(red: 0.7, green: 0.4, blue: 0.85).opacity(0.4)
                                : Color(red: 0.6, green: 0.35, blue: 0.75).opacity(hoveredItemID == item.id ? 0.4 : 0.1),
                        lineWidth: isSelected ? 2 : (item.isSensitive ? 1.5 : 1)
                    )
            )
            .shadow(color: Color(red: 0.5, green: 0.2, blue: 0.7).opacity((hoveredItemID == item.id || isSelected) ? 0.3 : 0), radius: 8, y: 2)
            .animation(.easeInOut(duration: 0.15), value: hoveredItemID)
            .animation(.easeInOut(duration: 0.2), value: showCopyConfirmation)
            .contentShape(Rectangle())
            .draggable(item) {
                Label(
                    item.type == .text ? "Text" : "Image",
                    systemImage: item.type == .text ? "doc.text" : "photo"
                )
            }
            .simultaneousGesture(TapGesture().onEnded {
                if isMultiSelectActive {
                    if selectedItems.contains(item.id) {
                        selectedItems.remove(item.id)
                    } else {
                        selectedItems.insert(item.id)
                    }
                } else if let observer = clipboardObserver {
                    PasteboardWriter.write(item, imageStore: imageStore, clipboardObserver: observer)
                    showCopyConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        showCopyConfirmation = false
                    }
                }
            })
            .onHover { hovering in
                hoveredItemID = hovering ? item.id : nil
            }
            .contextMenu {
                Button {
                    onTogglePin?()
                } label: {
                    Label(
                        item.isPinned ? "Unpin" : "Pin",
                        systemImage: item.isPinned ? "pin.slash" : "pin"
                    )
                }

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

    @ViewBuilder
    private var cardContent: some View {
        ZStack {
            // Main card content
            if item.type == .image {
                imageCardContent
            } else {
                textCardContent
            }

            // Timestamp overlay — bottom-right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(item.timestamp, style: .relative)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(5)

            // Multi-select checkbox — top-left
            if isMultiSelectActive {
                VStack {
                    HStack {
                        Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedItems.contains(item.id) ? Color(red: 0.7, green: 0.4, blue: 0.85) : .secondary)
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

            // Pin icon overlay — top-left (when not in multi-select)
            if !isMultiSelectActive && item.isPinned {
                VStack {
                    HStack {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(red: 0.7, green: 0.4, blue: 0.85))
                            .padding(3)
                            .background(.ultraThinMaterial, in: Circle())
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
                    .foregroundStyle(.white, Color(red: 0.6, green: 0.35, blue: 0.75).opacity(0.85))
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 36, height: 36)
                    )
                    .shadow(color: Color(red: 0.5, green: 0.2, blue: 0.7).opacity(0.4), radius: 4, y: 1)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var sensitiveCardContent: some View {
        ZStack {
            // Striped background pattern to visually signal redaction
            Color(red: 0.35, green: 0.15, blue: 0.45).opacity(0.15)

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
                            .foregroundStyle(Color(red: 0.7, green: 0.4, blue: 0.85))
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
                                .background(Color(red: 0.7, green: 0.4, blue: 0.85), in: Circle())
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
                    .foregroundStyle(Color(red: 0.7, green: 0.4, blue: 0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.7, green: 0.4, blue: 0.85).opacity(0.15))
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
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
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
                attributed[attrStart..<attrEnd].foregroundColor = Color(red: 0.7, green: 0.4, blue: 0.85)
                attributed[attrStart..<attrEnd].font = .system(size: 10, weight: .bold)
            }
            searchStart = range.upperBound
        }

        return attributed
    }
}
