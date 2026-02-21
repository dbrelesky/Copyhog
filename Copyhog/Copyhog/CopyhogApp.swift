import SwiftUI

@main
struct CopyhogApp: App {
    var body: some Scene {
        MenuBarExtra {
            Text("Copyhog")
                .frame(width: 360, height: 480)
        } label: {
            Image(systemName: "circle.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
