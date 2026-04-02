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
                }

                Button {
                    let placemark = MKPlacemark(coordinate: hazard.coordinate)
                    let item = MKMapItem(placemark: placemark)
                    item.name = hazard.name
                    item.openInMaps()
                } label: {
                    Label("View in Maps", systemImage: "map")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .controlSize(.large)
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
}
