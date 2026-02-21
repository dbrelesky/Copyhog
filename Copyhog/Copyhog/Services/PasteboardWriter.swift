import AppKit
import Foundation

@MainActor
struct PasteboardWriter {

    /// Copies a single ClipItem to the system clipboard.
    static func write(
        _ item: ClipItem,
        imageStore: ImageStore,
        clipboardObserver: ClipboardObserver
    ) {
        clipboardObserver.skipNextChange()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text:
            pasteboard.setString(item.content ?? "", forType: .string)

        case .image:
            guard let filePath = item.filePath,
                  let image = imageStore.loadImage(relativePath: filePath),
                  let tiffData = image.tiffRepresentation else {
                return
            }
            pasteboard.setData(tiffData, forType: .tiff)
        }
    }

    /// Copies multiple ClipItems to the system clipboard.
    /// Text items are concatenated with newlines; image items are written as file URLs.
    static func writeMultiple(
        _ items: [ClipItem],
        imageStore: ImageStore,
        clipboardObserver: ClipboardObserver
    ) {
        guard !items.isEmpty else { return }

        clipboardObserver.skipNextChange()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        var objects: [NSPasteboardWriting] = []

        // Concatenate text items
        let textContent = items
            .filter { $0.type == .text }
            .compactMap { $0.content }
            .joined(separator: "\n")

        if !textContent.isEmpty {
            objects.append(textContent as NSString)
        }

        // Add image file URLs
        for item in items where item.type == .image {
            guard let filePath = item.filePath else { continue }
            let url = imageStore.resolveURL(relativePath: filePath)
            objects.append(url as NSURL)
        }

        pasteboard.writeObjects(objects)
    }
}
