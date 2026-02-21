import SwiftUI

struct ItemRow: View {
    let item: ClipItem
    let imageStore: ImageStore
    @Binding var hoveredItemID: UUID?

    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail area
            if item.type == .image {
                if let thumbPath = item.thumbnailPath,
                   let nsImage = imageStore.loadImage(relativePath: thumbPath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 64, height: 64)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            } else {
                Image(systemName: "doc.text")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, height: 64)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
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
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            hoveredItemID == item.id
                ? Color.secondary.opacity(0.1)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            hoveredItemID = hovering ? item.id : nil
        }
    }
}
