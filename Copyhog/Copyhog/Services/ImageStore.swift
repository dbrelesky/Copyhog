import AppKit
import Foundation

final class ImageStore: @unchecked Sendable {

    private let baseDirectory: URL
    private let thumbnailCache = NSCache<NSString, NSImage>()

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        baseDirectory = appSupport.appendingPathComponent("Copyhog", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )

        thumbnailCache.countLimit = 200
    }

    // MARK: - Public API

    /// Saves full image and generates a 64x64 thumbnail.
    /// Returns relative paths (relative to App Support/Copyhog/) or nil on failure.
    func saveImage(_ imageData: Data, id: UUID) -> (filePath: String, thumbnailPath: String)? {
        let fileName = "\(id.uuidString).png"
        let thumbName = "\(id.uuidString)_thumb.png"

        let fullURL = baseDirectory.appendingPathComponent(fileName)
        let thumbURL = baseDirectory.appendingPathComponent(thumbName)

        // Save full image
        guard let pngData = pngData(from: imageData) else { return nil }
        do {
            try pngData.write(to: fullURL)
        } catch {
            return nil
        }

        // Generate and save thumbnail
        if let thumbnail = generateThumbnail(from: imageData, size: NSSize(width: 64, height: 64)) {
            try? thumbnail.write(to: thumbURL)
        }

        return (filePath: fileName, thumbnailPath: thumbName)
    }

    /// Loads an image from a relative path under App Support/Copyhog/.
    /// Results are cached in memory; subsequent calls return the cached copy.
    func loadImage(relativePath: String) -> NSImage? {
        let key = relativePath as NSString

        // Check cache first
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }

        // Load from disk
        let url = baseDirectory.appendingPathComponent(relativePath)
        guard let image = NSImage(contentsOf: url) else { return nil }

        // Store in cache
        thumbnailCache.setObject(image, forKey: key)
        return image
    }

    /// Resolves a relative path to a full URL under App Support/Copyhog/.
    func resolveURL(relativePath: String) -> URL {
        baseDirectory.appendingPathComponent(relativePath)
    }

    /// Invalidates the cached thumbnail for the given relative path.
    func invalidateCache(relativePath: String) {
        thumbnailCache.removeObject(forKey: relativePath as NSString)
    }

    /// Deletes an image file at the given relative path and invalidates its cache entry.
    func deleteImage(relativePath: String) {
        invalidateCache(relativePath: relativePath)
        let url = baseDirectory.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Private Helpers

    private func pngData(from imageData: Data) -> Data? {
        guard let image = NSImage(data: imageData) else { return nil }
        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private func generateThumbnail(from imageData: Data, size: NSSize) -> Data? {
        guard let image = NSImage(data: imageData) else { return nil }

        let thumbImage = NSImage(size: size)
        thumbImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        thumbImage.unlockFocus()

        guard let tiffData = thumbImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
