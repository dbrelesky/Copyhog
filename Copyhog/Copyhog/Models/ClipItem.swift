import Foundation

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
