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
    ///
    /// Writes three complementary pasteboard types on a single item so every app
    /// receives all content in the richest format it supports:
    /// - `.rtfd`   — rich text with embedded images (Notes, TextEdit, Pages, Mail, Messages)
    /// - `.string` — concatenated text for plain-text apps (Terminal, code editors)
    /// - `.tiff`   — first image for apps that only read raw image data
    static func writeMultiple(
        _ items: [ClipItem],
        imageStore: ImageStore,
        clipboardObserver: ClipboardObserver
    ) {
        guard !items.isEmpty else { return }

        clipboardObserver.skipNextChange()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Build an attributed string with all items (text + inline images)
        let attributed = NSMutableAttributedString()
        var isFirst = true

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
                   let image = imageStore.loadImage(relativePath: filePath) {
                    let attachment = NSTextAttachment()
                    let cell = NSTextAttachmentCell(imageCell: image)
                    attachment.attachmentCell = cell
                    attributed.append(NSAttributedString(attachment: attachment))
                    isFirst = false
                }
            }
        }

        // RTFD embeds images inline — rich text apps paste ALL items at once
        let range = NSRange(location: 0, length: attributed.length)
        if let rtfdData = attributed.rtfd(from: range, documentAttributes: [:]) {
            pasteboard.setData(rtfdData, forType: .rtfd)
        }

        // Plain text fallback for text-only apps
        let allText = items
            .filter { $0.type == .text }
            .compactMap { $0.content }
            .joined(separator: "\n\n")

        if !allText.isEmpty {
            pasteboard.setString(allText, forType: .string)
        }

        // TIFF fallback — first image for apps that only read raw image data
        if let firstImage = items.first(where: { $0.type == .image }),
           let filePath = firstImage.filePath,
           let image = imageStore.loadImage(relativePath: filePath),
           let tiffData = image.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
        }
    }
}
