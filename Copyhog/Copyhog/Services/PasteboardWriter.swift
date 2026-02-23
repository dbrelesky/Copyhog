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
                clipboardObserver.finishOwnWrite()
                return
            }
            pasteboard.setData(tiffData, forType: .tiff)
        }

        clipboardObserver.finishOwnWrite()
    }

    /// Copies multiple ClipItems to the system clipboard on a single pasteboard item.
    ///
    /// Multi-select must preserve *all* selected items.
    ///
    /// To avoid target apps pasting only a subset, this method only publishes
    /// formats that can carry the full selection:
    /// - `.rtfd` for mixed/image-rich content (text + embedded images)
    /// - `.string` only for text-only selections
    static func writeMultiple(
        _ items: [ClipItem],
        imageStore: ImageStore,
        clipboardObserver: ClipboardObserver
    ) {
        guard !items.isEmpty else { return }

        clipboardObserver.skipNextChange()

        // Build an attributed string with all items (text + inline images).
        // Images are embedded via FileWrapper so the RTFD serializer includes
        // the actual image bytes — NSTextAttachmentCell alone only displays but
        // does not serialize image data into the RTFD archive.
        let attributed = NSMutableAttributedString()
        var isFirst = true
        var imageIndex = 0

        for item in items {
            if !isFirst {
                attributed.append(NSAttributedString(string: "\n\n"))
            }

            switch item.type {
            case .text:
                attributed.append(NSAttributedString(string: item.content ?? ""))
                isFirst = false

            case .image:
                if let filePath = item.filePath,
                   let image = imageStore.loadImage(relativePath: filePath),
                   let tiffData = image.tiffRepresentation {
                    let attachment = NSTextAttachment()
                    let wrapper = FileWrapper(regularFileWithContents: tiffData)
                    wrapper.preferredFilename = "image\(imageIndex).tiff"
                    attachment.fileWrapper = wrapper
                    attributed.append(NSAttributedString(attachment: attachment))
                    imageIndex += 1
                    isFirst = false
                }
            }
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // RTFD — single item with full mixed payload for rich-text apps
        let range = NSRange(location: 0, length: attributed.length)
        if let rtfdData = attributed.rtfd(from: range, documentAttributes: [:]) {
            pasteboard.setData(rtfdData, forType: .rtfd)
        }

        // Plain-text fallback is only safe for text-only batches.
        // For mixed/image selections, .string would drop images in many apps.
        let allText = items
            .filter { $0.type == .text }
            .compactMap { $0.content }
            .joined(separator: "\n\n")
        let hasImages = items.contains { $0.type == .image }
        if !hasImages && !allText.isEmpty {
            pasteboard.setString(allText, forType: .string)
        }

        clipboardObserver.finishOwnWrite()
    }
}
