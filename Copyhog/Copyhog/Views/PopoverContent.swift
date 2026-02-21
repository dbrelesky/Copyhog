import SwiftUI

struct PopoverContent: View {
    @EnvironmentObject var store: ClipItemStore
    @State private var hoveredItemID: UUID?
    @State private var isMultiSelectActive = false
    @State private var selectedItems: Set<UUID> = []
    @State private var showWipeConfirmation = false

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

                    // Toolbar: multi-select toggle and batch copy
                    HStack {
                        Button {
                            isMultiSelectActive.toggle()
                            if !isMultiSelectActive {
                                selectedItems.removeAll()
                            }
                        } label: {
                            Image(systemName: isMultiSelectActive
                                  ? "checklist.checked"
                                  : "checklist.unchecked")
                        }
                        .buttonStyle(.borderless)
                        .help(isMultiSelectActive ? "Exit multi-select" : "Multi-select")

                        Spacer()

                        if isMultiSelectActive && !selectedItems.isEmpty,
                           let observer = store.clipboardObserver {
                            Button("Copy \(selectedItems.count) items") {
                                let itemsToCopy = store.items.filter { selectedItems.contains($0.id) }
                                PasteboardWriter.writeMultiple(
                                    itemsToCopy,
                                    imageStore: store.imageStore,
                                    clipboardObserver: observer
                                )
                                selectedItems.removeAll()
                                isMultiSelectActive = false
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        Button {
                            showWipeConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Hog Wipe — clear all")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                    Divider()

                    List {
                        ForEach(store.items) { item in
                            ItemRow(
                                item: item,
                                imageStore: store.imageStore,
                                hoveredItemID: $hoveredItemID,
                                isMultiSelectActive: isMultiSelectActive,
                                selectedItems: $selectedItems,
                                clipboardObserver: store.clipboardObserver
                            )
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let item = store.items[index]
                                selectedItems.remove(item.id)
                                store.remove(id: item.id)
                            }
                        }
                    }
                    .listStyle(.plain)

                    Divider()

                    HStack {
                        Spacer()
                        Button("Quit Copyhog") {
                            NSApplication.shared.terminate(nil)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .controlSize(.small)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .alert("Hog Wipe", isPresented: $showWipeConfirmation) {
                    Button("Wipe All", role: .destructive) {
                        store.removeAll()
                        selectedItems.removeAll()
                        isMultiSelectActive = false
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will permanently delete all clipboard history items.")
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
