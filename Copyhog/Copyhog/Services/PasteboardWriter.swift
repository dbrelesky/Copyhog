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

    /// Copies multiple ClipItems to the system clipboard as a single combined string.
    /// Text items are concatenated with double newlines so every app receives all content on paste.
    /// When images are included alongside text, only the text portions are combined.
    /// When all items are images, the first image is written to the clipboard.
    static func writeMultiple(
        _ items: [ClipItem],
        imageStore: ImageStore,
        clipboardObserver: ClipboardObserver
    ) {
        guard !items.isEmpty else { return }

        clipboardObserver.skipNextChange()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let allText = items
            .filter { $0.type == .text }
            .compactMap { $0.content }
            .joined(separator: "\n\n")

        if !allText.isEmpty {
            pasteboard.setString(allText, forType: .string)
        } else if let firstImage = items.first(where: { $0.type == .image }),
                  let filePath = firstImage.filePath,
                  let image = imageStore.loadImage(relativePath: filePath),
                  let tiffData = image.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
        }
    }
}
