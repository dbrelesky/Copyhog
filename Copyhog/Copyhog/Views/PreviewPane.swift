import SwiftUI

struct PreviewPane: View {
    let item: ClipItem?
    let imageStore: ImageStore

    var body: some View {
        Group {
            if let item {
                switch item.type {
                case .image:
                    if let filePath = item.filePath,
                       let nsImage = imageStore.loadImage(relativePath: filePath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .text:
                    ScrollView {
                        Text(item.content ?? "")
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                Image(systemName: "clipboard")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color(red: 0.55, green: 0.35, blue: 0.2).opacity(0.06)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }
}
