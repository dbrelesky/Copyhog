import SwiftUI

struct PopoverContent: View {
    @EnvironmentObject var store: ClipItemStore
    @State private var hoveredItemID: UUID?
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
    @State private var copyCount: Int = 0

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
                if !selectedItems.isEmpty {
                    copyMultiSelectedItems()
                } else {
                    copySelectedItem()
                }
                return nil
            case 8: // C key
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                if flags.contains([.control, .command]) {
                    dismissPopover()
                    return nil
                }
                if flags.contains(.command) && !flags.contains(.control) {
                    if !selectedItems.isEmpty {
                        copyMultiSelectedItems()
                    } else {
                        copySelectedItem()
                    }
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
            case 18, 19, 20, 21, 23, 22, 26, 28, 25: // digit keys 1–9
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                if flags.contains(.command) && !flags.contains(.control) {
                    let digitMap: [UInt16: Int] = [18:0, 19:1, 20:2, 21:3, 23:4, 22:5, 26:6, 28:7, 25:8]
                    if let idx = digitMap[keyCode], idx < store.displayItems.count {
                        selectedIndex = idx
                        copySelectedItem()
                    }
                    return nil
                }
                return event
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
        selectedItems.removeAll()
        PasteboardWriter.write(item, imageStore: store.imageStore, clipboardObserver: observer)
        copyCount = 1
        copiedItemID = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            copiedItemID = nil
        }
        AutoPasteService.pasteAfterDismiss()
    }

    private func copyMultiSelectedItems() {
        guard let observer = store.clipboardObserver else { return }
        let itemsToCopy = store.items.filter { selectedItems.contains($0.id) }
        guard !itemsToCopy.isEmpty else {
            copyCount = 0
            return
        }
        PasteboardWriter.writeMultiple(
            itemsToCopy,
            imageStore: store.imageStore,
            clipboardObserver: observer
        )
        copyCount = itemsToCopy.count
    }

    private func dismissPopover() {
        for window in NSApp.windows where window is NSPanel {
            window.close()
        }
    }

    var body: some View {
        Group {
            if store.items.isEmpty {
                VStack(spacing: 0) {
                    // Pig icon with speech bubble
                    HStack(alignment: .center, spacing: 6) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 160, height: 160)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hey!")
                            Text("I'm Copyhog.")
                        }
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            SpeechBubble()
                                .fill(.white)
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        )
                    }
                    .padding(.top, 24)

                    // Conversational body
                    Text("I live in your menu bar and remember everything you copy — screenshots, text, code, links. My clipboard is empty right now and I'm starving!")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)

                    // Pro tip pill
                    Text("Pro Tip: Press ⌃⌘C to open me anytime")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.purple.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(.purple.opacity(0.2), lineWidth: 0.5)
                        )
                        .padding(.top, 16)

                    Spacer()

                    // Quit button pinned to bottom
                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Quit Copyhog", systemImage: "power")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray.opacity(0.3))
                    .foregroundStyle(.primary)
                    .controlSize(.small)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    PreviewPane(item: previewItem, imageStore: store.imageStore)
                        .frame(height: 200)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)

                    // Toolbar: search pill, copy status, settings
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

                        Spacer()

                        if copyCount > 0 {
                            Text("\(copyCount) Copied")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.accent)
                                .clipShape(Capsule())
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
                                showWipeConfirmation = false
                            }
                            .controlSize(.small)
                            .buttonStyle(.borderedProminent)
                            .tint(.yellow)
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
                                        ForEach(Array(store.displayItems.enumerated()), id: \.element.id) { index, item in
                                            ItemRow(
                                                item: item,
                                                imageStore: store.imageStore,
                                                hoveredItemID: $hoveredItemID,
                                                selectedItems: $selectedItems,
                                                clipboardObserver: store.clipboardObserver,
                                                isSelected: selectedIndex.flatMap { idx in idx < store.displayItems.count ? store.displayItems[idx].id : nil } == item.id,
                                                searchQuery: store.searchQuery,
                                                copiedItemID: copiedItemID,
                                                gridIndex: index,
                                                onCopy: {
                                                    copyCount = 1
                                                },
                                                onCommandSelectionChanged: {
                                                    copyMultiSelectedItems()
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
            copyCount = 0
            selectedItems.removeAll()
            isSearchFocused = false
        }
        .onChange(of: store.searchQuery) { _, _ in
            selectedIndex = store.displayItems.isEmpty ? nil : 0
        }
    }
}

private struct SpeechBubble: Shape {
    func path(in rect: CGRect) -> Path {
        let cornerRadius: CGFloat = 12
        let tailWidth: CGFloat = 12
        let tailHeight: CGFloat = 10

        var path = Path()

        // Main rounded rectangle
        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )

        // Comic-style tail pointing left toward the pig icon
        let tailTop = rect.midY - tailWidth / 2
        let tailBottom = rect.midY + tailWidth / 2

        path.move(to: CGPoint(x: rect.minX, y: tailTop))
        path.addCurve(
            to: CGPoint(x: rect.minX - tailHeight, y: rect.midY + 4),
            control1: CGPoint(x: rect.minX - 4, y: tailTop),
            control2: CGPoint(x: rect.minX - tailHeight, y: rect.midY - 2)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: tailBottom),
            control1: CGPoint(x: rect.minX - tailHeight + 2, y: rect.midY + 8),
            control2: CGPoint(x: rect.minX - 2, y: tailBottom)
        )

        return path
    }
}

#Preview {
    PopoverContent()
        .environmentObject(ClipItemStore())
}
