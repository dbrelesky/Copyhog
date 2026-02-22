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
    let isSensitive: Bool       // True if captured from an excluded app — content is redacted

    enum ItemType: String, Codable {
        case text
        case image
    }

    enum CodingKeys: String, CodingKey {
        case id, type, content, thumbnailPath, filePath, timestamp, isSensitive
    }

    init(id: UUID, type: ItemType, content: String?, thumbnailPath: String?, filePath: String?, timestamp: Date, isSensitive: Bool = false) {
        self.id = id
        self.type = type
        self.content = content
        self.thumbnailPath = thumbnailPath
        self.filePath = filePath
        self.timestamp = timestamp
        self.isSensitive = isSensitive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ItemType.self, forKey: .type)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        thumbnailPath = try container.decodeIfPresent(String.self, forKey: .thumbnailPath)
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isSensitive = try container.decodeIfPresent(Bool.self, forKey: .isSensitive) ?? false
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
