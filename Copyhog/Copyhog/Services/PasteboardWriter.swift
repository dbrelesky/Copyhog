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

    /// Copies multiple ClipItems to the system clipboard as individual pasteboard items.
    /// Each item gets its own pasteboard entry so apps that support multi-paste receive all items.
    /// Text items are also concatenated as a combined string on the first item for broad compatibility.
    static func writeMultiple(
        _ items: [ClipItem],
        imageStore: ImageStore,
        clipboardObserver: ClipboardObserver
    ) {
        guard !items.isEmpty else { return }

        clipboardObserver.skipNextChange()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        var pbItems: [NSPasteboardItem] = []

        // Build a combined text string for apps that only read the first pasteboard item
        let allText = items
            .filter { $0.type == .text }
            .compactMap { $0.content }
            .joined(separator: "\n\n")

        for (index, item) in items.enumerated() {
            let pbItem = NSPasteboardItem()

            switch item.type {
            case .text:
                if index == 0 && !allText.isEmpty {
                    // First item carries the combined text for single-paste apps
                    pbItem.setString(allText, forType: .string)
                } else {
                    pbItem.setString(item.content ?? "", forType: .string)
                }

            case .image:
                if let filePath = item.filePath,
                   let image = imageStore.loadImage(relativePath: filePath),
                   let tiffData = image.tiffRepresentation {
                    pbItem.setData(tiffData, forType: .tiff)
                }
                if let filePath = item.filePath {
                    let url = imageStore.resolveURL(relativePath: filePath)
                    pbItem.setString(url.absoluteString, forType: .fileURL)
                }
            }

            pbItems.append(pbItem)
        }

        pasteboard.writeObjects(pbItems)
    }
}
