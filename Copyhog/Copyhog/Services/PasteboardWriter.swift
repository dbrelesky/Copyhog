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
    /// Text items are concatenated with double-newline separators.
    /// Image items are written as file URLs (Finder) with TIFF data for the first image (rich-paste apps).
    static func writeMultiple(
        _ items: [ClipItem],
        imageStore: ImageStore,
        clipboardObserver: ClipboardObserver
    ) {
        guard !items.isEmpty else { return }

        clipboardObserver.skipNextChange()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Separate by type
        let textItems = items.filter { $0.type == .text }
        let imageItems = items.filter { $0.type == .image }

        // Concatenate all text content
        let textContent = textItems.compactMap { $0.content }.joined(separator: "\n\n")

        // Resolve image file URLs
        let imageURLs: [URL] = imageItems.compactMap { item in
            guard let filePath = item.filePath else { return nil }
            return imageStore.resolveURL(relativePath: filePath)
        }

        if !textContent.isEmpty && imageURLs.isEmpty {
            // Text only: write directly as a single string (most reliable)
            pasteboard.setString(textContent, forType: .string)
        } else if textContent.isEmpty && !imageURLs.isEmpty {
            // Images only: write file URLs for Finder + TIFF data for rich-paste apps
            pasteboard.writeObjects(imageURLs.map { $0 as NSURL })
            // Also write first image as TIFF so apps like Preview/Slack can paste it
            if let firstPath = imageItems.first?.filePath,
               let image = imageStore.loadImage(relativePath: firstPath),
               let tiffData = image.tiffRepresentation {
                pasteboard.setData(tiffData, forType: .tiff)
            }
        } else {
            // Mixed: primary item has text + first image, extra images as file URLs
            let primaryItem = NSPasteboardItem()
            primaryItem.setString(textContent, forType: .string)
            if let firstURL = imageURLs.first {
                primaryItem.setString(firstURL.absoluteString, forType: .fileURL)
            }
            var pbItems: [NSPasteboardWriting] = [primaryItem]
            for url in imageURLs.dropFirst() {
                pbItems.append(url as NSURL)
            }
            pasteboard.writeObjects(pbItems)
        }
    }
}
