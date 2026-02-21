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
                    HStack {
                        if item.type == .text {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.secondary)
                            Text(item.content ?? "")
                                .lineLimit(2)
                                .font(.caption)
                        } else {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                            Text("Image")
                                .font(.caption)
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
