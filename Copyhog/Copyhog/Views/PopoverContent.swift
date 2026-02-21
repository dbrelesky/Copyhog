import SwiftUI

struct PopoverContent: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Copyhog")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No items yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(width: 360, height: 480)
    }
}

#Preview {
    PopoverContent()
}
