import SwiftUI

struct PopoverContent: View {
    @EnvironmentObject var store: ClipItemStore

    var body: some View {
        VStack {
            if store.items.isEmpty {
                Spacer()
                Text("Copyhog")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No items yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                List(store.items) { item in
                    HStack(spacing: 8) {
                        if item.type == .text {
                            Image(systemName: "doc.text")
                                .frame(width: 40, height: 40)
                                .foregroundStyle(.secondary)
                            Text(item.content ?? "")
                                .lineLimit(2)
                                .font(.caption)
                        } else if let thumbPath = item.thumbnailPath,
                                  let nsImage = store.imageStore.loadImage(relativePath: thumbPath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Image(systemName: "photo")
                                .frame(width: 40, height: 40)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(width: 360, height: 480)
    }
}

#Preview {
    PopoverContent()
        .environmentObject(ClipItemStore())
}
