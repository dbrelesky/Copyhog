import SwiftUI

struct ItemRow: View {
    let item: ClipItem
    let imageStore: ImageStore
    @Binding var hoveredItemID: UUID?
    let isMultiSelectActive: Bool
    @Binding var selectedItems: Set<UUID>
    let clipboardObserver: ClipboardObserver?
    @State private var showCopyConfirmation = false

    var body: some View {
        HStack(spacing: 8) {
            // Multi-select checkbox (outside draggable area)
            if isMultiSelectActive {
                Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedItems.contains(item.id) ? Color(red: 0.7, green: 0.4, blue: 0.85) : .secondary)
                    .font(.title3)
            }

            // Inner content with draggable
            rowContent
                .draggable(item) {
                    Label(
                        item.type == .text ? "Text" : "Image",
                        systemImage: item.type == .text ? "doc.text" : "photo"
                    )
                }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.6, green: 0.35, blue: 0.75).opacity(hoveredItemID == item.id ? 0.15 : 0))
        )
        .animation(.easeInOut(duration: 0.15), value: hoveredItemID)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .animation(.easeInOut(duration: 0.2), value: showCopyConfirmation)
        .contentShape(Rectangle())
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
    }

    @ViewBuilder
    private var rowContent: some View {
        HStack(spacing: 8) {
            // Thumbnail area
            thumbnailView
                .overlay(alignment: .topLeading) {
                    if showCopyConfirmation {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color(red: 0.6, green: 0.35, blue: 0.75).opacity(0.7))
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 24, height: 24)
                            )
                            .shadow(color: Color(red: 0.5, green: 0.2, blue: 0.7).opacity(0.4), radius: 4, y: 1)
                            .offset(x: -6, y: -6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

            // Content area

            if item.type == .text {
                VStack(alignment: .leading) {
                    Text(item.content ?? "")
                        .lineLimit(2)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer()
            }

            // Timestamp
            Text(item.timestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if item.type == .image {
            if let thumbPath = item.thumbnailPath,
               let nsImage = imageStore.loadImage(relativePath: thumbPath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                    )
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, height: 64)
                    .background(Color(red: 0.4, green: 0.2, blue: 0.5).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        } else {
            Image(systemName: "doc.text")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 64, height: 64)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
