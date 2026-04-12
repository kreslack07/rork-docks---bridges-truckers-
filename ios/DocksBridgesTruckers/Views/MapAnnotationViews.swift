import SwiftUI

struct DockAnnotationView: View {
    let dock: Dock

    var body: some View {
        Image(systemName: dock.businessCategory.icon)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(AppTheme.accent, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .accessibilityLabel("\(dock.name), \(dock.businessCategory.label)")
    }
}

struct HazardAnnotationView: View {
    let hazard: Hazard
    let status: HazardStatus

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: hazard.type.icon)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(status.color, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

            Text(annotationLabel)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(status.color)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hazard.name), \(hazard.type.label), \(status.label), \(annotationLabel)")
    }

    private var annotationLabel: String {
        if hazard.type == .weight_limit, let limit = hazard.weightLimit {
            return String(format: "%.0ft", limit)
        }
        return String(format: "%.1fm", hazard.clearanceHeight)
    }
}

struct NearbyPlaceAnnotationView: View {
    let place: NearbyPlace

    var body: some View {
        Image(systemName: place.category.icon)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(place.category.color, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
    }
}
