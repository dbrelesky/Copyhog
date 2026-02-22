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
                    systemImage: "nose.fill",
                    description: Text("Nothing saved to your clipboard, start hoggin' and I'll keep it all here.")
                )
                .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    PreviewPane(item: previewItem, imageStore: store.imageStore)
                        .frame(height: 200)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)

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

                        SettingsMenu(showWipeConfirmation: $showWipeConfirmation)
                            .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    if showWipeConfirmation {
                        HStack {
                            Text("Remove all items?")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Cancel") {
                                showWipeConfirmation = false
                            }
                            .controlSize(.small)
                            Button("Wipe All") {
                                store.removeAll()
                                selectedItems.removeAll()
                                isMultiSelectActive = false
                                showWipeConfirmation = false
                            }
                            .controlSize(.small)
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 8)
                    }

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
                    .scrollContentBackground(.hidden)
                }
                .background(Color.orange.opacity(0.03))
            }
        }
        .frame(width: 400, height: 520)
        .background(.ultraThinMaterial)
        .tint(.accentColor)
    }
}

#Preview {
    PopoverContent()
        .environmentObject(ClipItemStore())
}
