import SwiftUI

struct PopoverContent: View {
    @EnvironmentObject var store: ClipItemStore
    @State private var hoveredItemID: UUID?

    private var previewItem: ClipItem? {
        if let hoveredID = hoveredItemID {
            return store.items.first { $0.id == hoveredID }
        }
        return store.items.first
    }

    var body: some View {
        Group {
            if store.items.isEmpty {
                ContentUnavailableView(
                    "No Clips Yet",
                    systemImage: "clipboard",
                    description: Text("Copy text or take a screenshot to get started")
                )
            } else {
                VStack(spacing: 0) {
                    PreviewPane(item: previewItem, imageStore: store.imageStore)
                        .frame(height: 200)

                    Divider()

                    List(store.items) { item in
                        ItemRow(
                            item: item,
                            imageStore: store.imageStore,
                            hoveredItemID: $hoveredItemID
                        )
                    }
                    .listStyle(.plain)
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
