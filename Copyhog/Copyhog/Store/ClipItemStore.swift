import Foundation

@MainActor
final class ClipItemStore: ObservableObject {

    @Published var items: [ClipItem] = []

    private let maxItems = 20
    private let storeURL: URL
    let imageStore: ImageStore
    var clipboardObserver: ClipboardObserver?

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
    }

    // MARK: - Public API

    func add(_ item: ClipItem) {
        items.insert(item, at: 0)

        // Purge oldest items beyond the cap
        while items.count > maxItems {
            let removed = items.removeLast()
            cleanupImages(for: removed)
        }

        save()
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(items)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            print("[ClipItemStore] Save failed: \(error)")
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
