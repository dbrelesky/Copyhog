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
                VStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 128, height: 128)
                    Text("No Clips Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text("Nothing in your clipboard yet, start screenshotting and copying text and I'll hog it all here.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            Label("Multi-Select", systemImage: isMultiSelectActive
                                  ? "checklist.checked"
                                  : "checklist.unchecked")
                            .font(.caption)
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

                    ScrollView {
                        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
                        let pinnedItems = store.items.filter { $0.isPinned }
                        let unpinnedItems = store.items.filter { !$0.isPinned }

                        LazyVStack(spacing: 0) {
                            // Pinned section
                            if !pinnedItems.isEmpty {
                                HStack {
                                    Label("Pinned", systemImage: "pin.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 8)

                                LazyVGrid(columns: columns, spacing: 8) {
                                    ForEach(pinnedItems) { item in
                                        ItemRow(
                                            item: item,
                                            imageStore: store.imageStore,
                                            hoveredItemID: $hoveredItemID,
                                            isMultiSelectActive: isMultiSelectActive,
                                            selectedItems: $selectedItems,
                                            clipboardObserver: store.clipboardObserver,
                                            onTogglePin: {
                                                withAnimation {
                                                    store.togglePin(id: item.id)
                                                }
                                            },
                                            onDelete: {
                                                selectedItems.remove(item.id)
                                                store.remove(id: item.id)
                                            },
                                            onMarkSensitive: {
                                                store.markSensitive(id: item.id)
                                            },
                                            onUnmarkSensitive: {
                                                store.unmarkSensitive(id: item.id)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 8)
                            }

                            // History section
                            if !unpinnedItems.isEmpty {
                                HStack {
                                    Label("History", systemImage: "clock")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 8)

                                LazyVGrid(columns: columns, spacing: 8) {
                                    ForEach(unpinnedItems) { item in
                                        ItemRow(
                                            item: item,
                                            imageStore: store.imageStore,
                                            hoveredItemID: $hoveredItemID,
                                            isMultiSelectActive: isMultiSelectActive,
                                            selectedItems: $selectedItems,
                                            clipboardObserver: store.clipboardObserver,
                                            onTogglePin: {
                                                withAnimation {
                                                    store.togglePin(id: item.id)
                                                }
                                            },
                                            onDelete: {
                                                selectedItems.remove(item.id)
                                                store.remove(id: item.id)
                                            },
                                            onMarkSensitive: {
                                                store.markSensitive(id: item.id)
                                            },
                                            onUnmarkSensitive: {
                                                store.unmarkSensitive(id: item.id)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
                .background(Color(red: 0.45, green: 0.2, blue: 0.55).opacity(0.06))
            }
        }
        .frame(width: 400, height: 520)
        .background {
            Color(red: 0.15, green: 0.08, blue: 0.2).opacity(0.65)
        }
        .tint(Color(red: 0.7, green: 0.4, blue: 0.85))
    }
}

#Preview {
    PopoverContent()
        .environmentObject(ClipItemStore())
}
