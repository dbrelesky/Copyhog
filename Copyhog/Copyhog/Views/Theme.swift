import SwiftUI

enum Theme {
    static let accent = Color(red: 0.6, green: 0.4, blue: 0.85)

    static func cardBackground(scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.primary.opacity(0.04)
            : Color.primary.opacity(0.03)
    }

    static func separator(scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.primary.opacity(0.1)
            : Color.primary.opacity(0.08)
    }
}
