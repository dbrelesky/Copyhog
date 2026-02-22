import SwiftUI

struct PopoverContent: View {
    @EnvironmentObject var store: ClipItemStore
    @State private var hoveredItemID: UUID?
    @State private var isMultiSelectActive = false
    @State private var selectedItems: Set<UUID> = []
    @State private var showWipeConfirmation = false
    @State private var isVisible = false
    @State private var searchText: String = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedIndex: Int? = nil
    @State private var isSearchFocused: Bool = false
    @State private var isSearchExpanded: Bool = false
    @State private var eventMonitor: Any? = nil
    @State private var copiedItemID: UUID? = nil

    private enum ArrowDirection {
        case up, down, left, right
    }

    private var previewItem: ClipItem? {
        if let hoveredID = hoveredItemID {
            return store.displayItems.first { $0.id == hoveredID }
        }
        if let index = selectedIndex, index < store.displayItems.count {
            return store.displayItems[index]
        }
        return store.displayItems.first
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        let keyCode = event.keyCode

        if isSearchFocused {
            switch keyCode {
            case 53: // Escape
                if !searchText.isEmpty {
                    searchText = ""
                    store.searchQuery = ""
                    return nil
                }
                // Collapse search pill
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isSearchExpanded = false
                }
                isSearchFocused = false
                NSApp.keyWindow?.makeFirstResponder(nil)
                if selectedIndex == nil && !store.displayItems.isEmpty {
                    selectedIndex = 0
                }
                return nil
            case 125: // Down arrow
                isSearchFocused = false
                // Resign first responder from search field so keystrokes go to list
                NSApp.keyWindow?.makeFirstResponder(nil)
                if selectedIndex == nil && !store.displayItems.isEmpty {
                    selectedIndex = 0
                }
                return nil
            case 48: // Tab
                if event.modifierFlags.contains(.shift) {
                    return event
                }
                isSearchFocused = false
                // Resign first responder from search field so keystrokes go to list
                NSApp.keyWindow?.makeFirstResponder(nil)
                if selectedIndex == nil && !store.displayItems.isEmpty {
                    selectedIndex = 0
                }
                return nil
            default:
                return event
            }
        } else {
            switch keyCode {
            case 125: // Down arrow
                handleArrowKey(.down)
                return nil
            case 126: // Up arrow
                handleArrowKey(.up)
                return nil
            case 124: // Right arrow
                handleArrowKey(.right)
                return nil
            case 123: // Left arrow
                handleArrowKey(.left)
                return nil
            case 36: // Enter/Return
                copySelectedItem()
                return nil
            case 8: // C key (Cmd+C)
                if event.modifierFlags.contains(.command) {
                    copySelectedItem()
                    return nil
                }
                return event
            case 53: // Escape
                if !searchText.isEmpty {
                    searchText = ""
                    store.searchQuery = ""
                    selectedIndex = store.displayItems.isEmpty ? nil : 0
                    return nil
                }
                if isSearchExpanded {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isSearchExpanded = false
                    }
                    return nil
                }
                dismissPopover()
                return nil
            case 48: // Tab
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isSearchExpanded = true
                }
                isSearchFocused = true
                return nil
            default:
                return event
            }
        }
    }

    private func handleArrowKey(_ direction: ArrowDirection) {
        let columns = 3
        switch direction {
        case .down:
            let next = (selectedIndex ?? -1) + columns
            if next < store.displayItems.count {
                selectedIndex = next
            }
        case .up:
            let next = (selectedIndex ?? 0) - columns
            if next >= 0 {
                selectedIndex = next
            }
        case .right:
            let next = (selectedIndex ?? -1) + 1
            if next < store.displayItems.count {
                selectedIndex = next
            }
        case .left:
            let next = (selectedIndex ?? 0) - 1
            if next >= 0 {
                selectedIndex = next
            }
        }
    }

    private func copySelectedItem() {
        guard let index = selectedIndex, index < store.displayItems.count else { return }
        let item = store.displayItems[index]
        guard let observer = store.clipboardObserver else { return }
        PasteboardWriter.write(item, imageStore: store.imageStore, clipboardObserver: observer)
        copiedItemID = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            copiedItemID = nil
        }
    }

    private func dismissPopover() {
        for window in NSApp.windows where window is NSPanel {
            window.close()
        }
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

                    // Toolbar: search pill, multi-select pill, batch copy, settings
                    HStack(spacing: 6) {
                        // Search pill — expands to input on tap
                        if isSearchExpanded {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 11, weight: .medium))

                                TextField("Search", text: $searchText, onEditingChanged: { editing in
                                    isSearchFocused = editing
                                })
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12))
                                    .onSubmit { }

                                Button {
                                    searchText = ""
                                    store.searchQuery = ""
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        isSearchExpanded = false
                                    }
                                    isSearchFocused = false
                                    NSApp.keyWindow?.makeFirstResponder(nil)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.8, anchor: .leading)),
                                removal: .opacity.combined(with: .scale(scale: 0.8, anchor: .leading))
                            ))
                        } else {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isSearchExpanded = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isSearchFocused = true
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("Search")
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.8, anchor: .leading)),
                                removal: .opacity.combined(with: .scale(scale: 0.8, anchor: .leading))
                            ))
                        }

                        // Multi-select pill
                        Button {
                            isMultiSelectActive.toggle()
                            if !isMultiSelectActive {
                                selectedItems.removeAll()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isMultiSelectActive
                                      ? "checklist.checked"
                                      : "checklist.unchecked")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(isMultiSelectActive ? Theme.accent : .secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        isMultiSelectActive
                                            ? Theme.accent.opacity(0.4)
                                            : Color.primary.opacity(0.1),
                                        lineWidth: 0.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .help(isMultiSelectActive ? "Exit multi-select" : "Multi-select")

                        Spacer()

                        if isMultiSelectActive && !selectedItems.isEmpty,
                           let observer = store.clipboardObserver {
                            Button("Copy \(selectedItems.count)") {
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .onChange(of: searchText) { _, newValue in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 150_000_000)
                            guard !Task.isCancelled else { return }
                            store.searchQuery = newValue
                        }
                    }

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

                    if store.displayItems.isEmpty && !store.searchQuery.isEmpty {
                        VStack(spacing: 8) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                            Text("No results for \"\(store.searchQuery)\"")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Try a different search term")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollViewReader { scrollProxy in
                            ScrollView {
                                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

                                LazyVStack(spacing: 0) {
                                    LazyVGrid(columns: columns, spacing: 8) {
                                        ForEach(store.displayItems) { item in
                                            ItemRow(
                                                item: item,
                                                imageStore: store.imageStore,
                                                hoveredItemID: $hoveredItemID,
                                                isMultiSelectActive: isMultiSelectActive,
                                                selectedItems: $selectedItems,
                                                clipboardObserver: store.clipboardObserver,
                                                isSelected: selectedIndex.flatMap { idx in idx < store.displayItems.count ? store.displayItems[idx].id : nil } == item.id,
                                                searchQuery: store.searchQuery,
                                                copiedItemID: copiedItemID,
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
                                            .id(item.id)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                }
                                .padding(.bottom, 8)
                            }
                            .onChange(of: selectedIndex) { _, newIndex in
                                if let idx = newIndex, idx < store.displayItems.count {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        scrollProxy.scrollTo(store.displayItems[idx].id, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                }
                .background(.clear)
            }
        }
        .frame(width: 400, height: 520)
        .tint(Theme.accent)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.98, anchor: .top)
        .offset(y: isVisible ? 0 : -4)
        .onAppear {
            withAnimation(.easeOut(duration: 0.15)) {
                isVisible = true
            }
            // Install keyboard event monitor
            if let existing = eventMonitor {
                NSEvent.removeMonitor(existing)
            }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                return handleKeyEvent(event)
            }
            // Default: first list item selected, not search field
            if !store.displayItems.isEmpty {
                selectedIndex = 0
            }
            isSearchFocused = false
            // Resign first responder so the search field doesn't capture keystrokes
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
        .onDisappear {
            isVisible = false
            searchText = ""
            store.searchQuery = ""
            isSearchExpanded = false
            searchTask?.cancel()
            // Remove keyboard event monitor
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
            selectedIndex = nil
            isSearchFocused = false
        }
        .onChange(of: store.searchQuery) { _, _ in
            selectedIndex = store.displayItems.isEmpty ? nil : 0
        }
    }
}

#Preview {
    PopoverContent()
        .environmentObject(ClipItemStore())
}
