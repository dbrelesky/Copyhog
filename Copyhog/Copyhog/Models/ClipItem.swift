import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ClipItem: Codable, Identifiable {
    let id: UUID
    let type: ItemType
    let content: String?        // Text content (nil for images)
    let thumbnailPath: String?  // Relative path to thumbnail in App Support
    let filePath: String?       // Relative path to full image in App Support
    let timestamp: Date

    enum ItemType: String, Codable {
        case text
        case image
    }
}

// MARK: - Transferable (drag-out support)

extension ClipItem: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { item in
            guard item.type == .text, let content = item.content else {
                throw CocoaError(.fileNoSuchFile)
            }
            return Data(content.utf8)
        }

        FileRepresentation(exportedContentType: .png) { item in
            guard item.type == .image, let filePath = item.filePath else {
                throw CocoaError(.fileNoSuchFile)
            }
            let url = ImageStore().resolveURL(relativePath: filePath)
            return SentTransferredFile(url)
        }

        // ProxyRepresentation for text items only — provides Finder/Slack compatibility
        // Images must NOT use ProxyRepresentation (it would export the file path as text
        // instead of letting FileRepresentation provide the actual image file)
        ProxyRepresentation { item in
            guard item.type == .text, let content = item.content else {
                throw CocoaError(.fileNoSuchFile)
            }
            return content
        }
    }
}
