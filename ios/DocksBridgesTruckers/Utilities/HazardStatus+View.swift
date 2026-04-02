import SwiftUI

extension HazardStatus {
    var color: Color {
        switch self {
        case .safe: .green
        case .tight: AppTheme.accent
        case .blocked: .red
        }
    }

    var icon: String {
        switch self {
        case .safe: "checkmark.circle.fill"
        case .tight: "exclamationmark.triangle.fill"
        case .blocked: "xmark.octagon.fill"
        }
    }
}
