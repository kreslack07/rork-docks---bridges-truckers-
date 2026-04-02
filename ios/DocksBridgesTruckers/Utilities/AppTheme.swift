import SwiftUI

nonisolated enum AppTheme {
    static let accent = Color(red: 0.95, green: 0.52, blue: 0.07)
    static let navy = Color(red: 0.04, green: 0.08, blue: 0.16)
    static let navyLight = Color(red: 0.08, green: 0.14, blue: 0.28)
    static let golden = Color(red: 1.0, green: 0.72, blue: 0.18)
    static let steel = Color(red: 0.70, green: 0.74, blue: 0.78)
    static let deepOrange = Color(red: 0.85, green: 0.40, blue: 0.02)
    static let nightSky = Color(red: 0.02, green: 0.05, blue: 0.12)

    static let splashGradient = LinearGradient(
        colors: [nightSky, navy, navyLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let onboardingGradient = LinearGradient(
        colors: [nightSky, navy, Color(red: 0.06, green: 0.10, blue: 0.22)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardGradient = LinearGradient(
        colors: [accent, deepOrange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let navyGradient = LinearGradient(
        colors: [navy, navyLight],
        startPoint: .top,
        endPoint: .bottom
    )

    static let subtleCardBackground = Color(.secondarySystemGroupedBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
}
