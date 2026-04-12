import SwiftUI
import MapKit

struct HazardDetailSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    let hazard: Hazard

    private var status: HazardStatus {
        viewModel.hazardStatus(hazard)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: hazard.type.icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(status.color.gradient, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(color: status.color.opacity(0.3), radius: 6, y: 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(hazard.name)
                            .font(.headline)
                        Text(hazard.type.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        viewModel.toggleHazardFavourite(hazard.id)
                    } label: {
                        Image(systemName: viewModel.isHazardFavourite(hazard.id) ? "bookmark.fill" : "bookmark")
                            .font(.title3)
                            .foregroundStyle(viewModel.isHazardFavourite(hazard.id) ? AppTheme.accent : .secondary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .sensoryFeedback(.impact, trigger: viewModel.isHazardFavourite(hazard.id))
                }

                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if hazard.type == .weight_limit, let limit = hazard.weightLimit {
                            Text(String(format: "%.0ft", limit))
                                .font(.title2.bold())
                                .foregroundStyle(status.color)
                        } else {
                            Text(String(format: "%.1fm", hazard.clearanceHeight))
                                .font(.title2.bold())
                                .foregroundStyle(status.color)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: status.icon)
                                .font(.caption)
                            Text(status.label)
                                .font(.caption.bold())
                        }
                        .foregroundStyle(status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(status.color.opacity(0.15), in: Capsule())
                    }
                }

                Divider()

                HStack(spacing: 16) {
                    if hazard.type == .weight_limit, let limit = hazard.weightLimit {
                        statCard(title: "Your Weight", value: String(format: "%.1ft", viewModel.truckProfile.weight), icon: "truck.box.fill")
                        statCard(title: "Weight Limit", value: String(format: "%.0ft", limit), icon: "scalemass.fill")
                    } else {
                        statCard(title: "Your Height", value: String(format: "%.1fm", viewModel.truckProfile.height), icon: "truck.box.fill")
                        statCard(title: "Clearance", value: String(format: "%.1fm", hazard.clearanceHeight), icon: "ruler")
                        if let weight = hazard.weightLimit {
                            statCard(title: "Weight Limit", value: String(format: "%.0ft", weight), icon: "scalemass.fill")
                        }
                    }
                }

                if let widthLimit = hazard.widthLimit {
                    let widthStatus = widthStatusFor(widthLimit)
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.caption.bold())
                            .foregroundStyle(widthStatus.color)
                            .frame(width: 28, height: 28)
                            .background(widthStatus.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Width Restriction")
                                .font(.caption.bold())
                            Text("Limit: \(String(format: "%.1fm", widthLimit)) · Your width: \(String(format: "%.1fm", viewModel.truckProfile.width))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 3) {
                            Image(systemName: widthStatus.icon)
                                .font(.system(size: 8))
                            Text(widthStatus.label)
                                .font(.system(size: 9, weight: .heavy))
                        }
                        .foregroundStyle(widthStatus.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(widthStatus.color.opacity(0.12), in: Capsule())
                    }
                    .padding(10)
                    .background(widthStatus.color.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(widthStatus.color.opacity(0.15), lineWidth: 1)
                    )
                }

                if let weightLimit = hazard.weightLimit, hazard.type != .weight_limit {
                    let weightStatus = weightStatusFor(weightLimit)
                    HStack(spacing: 12) {
                        Image(systemName: "scalemass.fill")
                            .font(.caption.bold())
                            .foregroundStyle(weightStatus.color)
                            .frame(width: 28, height: 28)
                            .background(weightStatus.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weight Restriction")
                                .font(.caption.bold())
                            Text("Limit: \(String(format: "%.0ft", weightLimit)) · Your weight: \(String(format: "%.1ft", viewModel.truckProfile.weight))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 3) {
                            Image(systemName: weightStatus.icon)
                                .font(.system(size: 8))
                            Text(weightStatus.label)
                                .font(.system(size: 9, weight: .heavy))
                        }
                        .foregroundStyle(weightStatus.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(weightStatus.color.opacity(0.12), in: Capsule())
                    }
                    .padding(10)
                    .background(weightStatus.color.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(weightStatus.color.opacity(0.15), lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label(hazard.road, systemImage: "road.lanes")
                    Label("\(hazard.city), \(hazard.state)", systemImage: "mappin")
                    Label("Verified: \(hazard.lastVerified)", systemImage: "checkmark.shield")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if !hazard.description.isEmpty {
                    Text(hazard.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                }

                HStack(spacing: 10) {
                    Button {
                        let placemark = MKPlacemark(coordinate: hazard.coordinate)
                        let item = MKMapItem(placemark: placemark)
                        item.name = hazard.name
                        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                    } label: {
                        Label("View in Maps", systemImage: "map")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .controlSize(.large)

                    ShareLink(
                        item: hazardShareText,
                        subject: Text(hazard.name),
                        message: Text("Hazard info from Docks & Bridges")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body.bold())
                            .frame(width: 50, height: 50)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)
                    .controlSize(.large)
                }
            }
            .padding()
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.bold())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func widthStatusFor(_ widthLimit: Double) -> HazardStatus {
        if viewModel.truckProfile.width > widthLimit { return .blocked }
        if viewModel.truckProfile.width > widthLimit - 0.3 { return .tight }
        return .safe
    }

    private func weightStatusFor(_ weightLimit: Double) -> HazardStatus {
        if viewModel.truckProfile.weight > weightLimit { return .blocked }
        if viewModel.truckProfile.weight > weightLimit * 0.9 { return .tight }
        return .safe
    }

    private var hazardShareText: String {
        var text = "⚠️ \(hazard.name)\n\(hazard.type.label) — \(hazard.road), \(hazard.city) \(hazard.state)"
        if hazard.type == .weight_limit, let limit = hazard.weightLimit {
            text += "\nWeight Limit: \(String(format: "%.0ft", limit))"
        } else {
            text += "\nClearance: \(String(format: "%.1fm", hazard.clearanceHeight))"
        }
        text += "\nVerified: \(hazard.lastVerified)"
        text += "\n— Docks & Bridges Trucker"
        return text
    }
}
