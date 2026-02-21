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

        // ProxyRepresentation needed for Finder/Slack compatibility
        // FileRepresentation alone fails on macOS 13-14 (Apple FB13454434)
        ProxyRepresentation { item in
            if item.type == .text {
                return item.content ?? ""
            } else if let filePath = item.filePath {
                return ImageStore().resolveURL(relativePath: filePath).absoluteString
            }
            return ""
        }
    }
}
