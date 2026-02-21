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
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
