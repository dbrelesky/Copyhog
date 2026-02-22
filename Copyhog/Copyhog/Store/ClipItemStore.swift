import Foundation
import SwiftUI

@MainActor
final class ClipItemStore: ObservableObject {

    @Published var items: [ClipItem] = []
    @Published var searchQuery: String = ""

    var displayItems: [ClipItem] {
        if searchQuery.isEmpty {
            return items
        }
        return items.filter { item in
            guard !item.isSensitive else { return false }
            if item.content?.localizedCaseInsensitiveContains(searchQuery) == true {
                return true
            }
            if item.sourceAppName?.localizedCaseInsensitiveContains(searchQuery) == true {
                return true
            }
            return false
        }
    }

    @AppStorage("historyLimit") var maxItems: Int = 20
    private let storeURL: URL
    let imageStore: ImageStore
    var clipboardObserver: ClipboardObserver?
    private var saveTask: Task<Void, Never>?

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let copyhogDir = appSupport.appendingPathComponent("Copyhog", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: copyhogDir,
            withIntermediateDirectories: true
        )

        storeURL = copyhogDir.appendingPathComponent("items.json")
        imageStore = ImageStore()

        load()

        // Sort so pinned items appear first on launch
        sortItems()
    }

    // MARK: - Public API

    func add(_ item: ClipItem) {
        items.insert(item, at: 0)

        // Re-sort to maintain pinned-first ordering
        sortItems()

        // Purge oldest unpinned items beyond the cap
        while items.count > maxItems {
            guard let lastUnpinnedIndex = items.lastIndex(where: { !$0.isPinned }) else {
                break // All items are pinned, cannot purge
            }
            let removed = items.remove(at: lastUnpinnedIndex)
            cleanupImages(for: removed)
        }

        scheduleSave()
    }

    func togglePin(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
        sortItems()
        scheduleSave()
    }

    func markSensitive(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let old = items[index]
        items[index] = ClipItem(
            id: old.id,
            type: old.type,
            content: old.content,
            thumbnailPath: old.thumbnailPath,
            filePath: old.filePath,
            timestamp: old.timestamp,
            isSensitive: true,
            isPinned: old.isPinned,
            sourceAppBundleID: old.sourceAppBundleID,
            sourceAppName: old.sourceAppName
        )
        scheduleSave()
    }

    func unmarkSensitive(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let old = items[index]
        items[index] = ClipItem(
            id: old.id,
            type: old.type,
            content: old.content,
            thumbnailPath: old.thumbnailPath,
            filePath: old.filePath,
            timestamp: old.timestamp,
            isSensitive: false,
            isPinned: old.isPinned,
            sourceAppBundleID: old.sourceAppBundleID,
            sourceAppName: old.sourceAppName
        )
        scheduleSave()
    }

    func remove(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let removed = items.remove(at: index)
        cleanupImages(for: removed)
        scheduleSave()
    }

    func removeAll() {
        for item in items {
            cleanupImages(for: item)
        }
        items = []
        scheduleSave()
    }

    // MARK: - Sorting

    private func sortItems() {
        items.sort { a, b in
            if a.isPinned != b.isPinned {
                return a.isPinned // pinned first
            }
            return a.timestamp > b.timestamp // newest first within each group
        }
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            guard !Task.isCancelled else { return }
            await self?.performSave()
        }
    }

    /// Flushes any pending debounced save immediately. Call before app termination.
    func flushSave() {
        saveTask?.cancel()
        saveTask = nil
        performSave()
    }

    private func performSave() {
        let snapshot = items
        let url = storeURL
        Task.detached {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            do {
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                print("[ClipItemStore] Save failed: \(error)")
            }
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let data = try Data(contentsOf: storeURL)
            items = try decoder.decode([ClipItem].self, from: data)
        } catch {
            print("[ClipItemStore] Load failed: \(error)")
        }
    }

    // MARK: - Cleanup

    private func cleanupImages(for item: ClipItem) {
        if let filePath = item.filePath {
            imageStore.deleteImage(relativePath: filePath)
        }
        if let thumbnailPath = item.thumbnailPath {
            imageStore.deleteImage(relativePath: thumbnailPath)
        }
    }
}
