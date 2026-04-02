import SwiftUI
import MapKit

struct DockDetailSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    let dock: Dock

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: dock.businessCategory.icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.cardGradient, in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(dock.name)
                            .font(.headline)
                        Text(dock.business)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        viewModel.toggleFavourite(dock.id)
                    } label: {
                        Image(systemName: viewModel.isFavourite(dock.id) ? "bookmark.fill" : "bookmark")
                            .font(.title3)
                            .foregroundStyle(viewModel.isFavourite(dock.id) ? AppTheme.accent : .secondary)
                    }
                    .sensoryFeedback(.impact, trigger: viewModel.isFavourite(dock.id))
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label(dock.dockType.label, systemImage: "arrow.left.arrow.right")
                    Label("\(dock.city), \(dock.state)", systemImage: "mappin")
                    Label(dock.address, systemImage: "location")
                    if let hours = dock.operatingHours {
                        Label(hours, systemImage: "clock")
                    }
                    if let phone = dock.phone {
                        Label(phone, systemImage: "phone")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if !dock.description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.subheadline.bold())
                        Text(dock.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !dock.accessNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Access Notes")
                            .font(.subheadline.bold())
                        Text(dock.accessNotes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if dock.isOffRoad {
                    Label("Off-Road Access", systemImage: "road.lanes.curved.right")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.accent)
                }

                Button {
                    let placemark = MKPlacemark(coordinate: dock.coordinate)
                    let item = MKMapItem(placemark: placemark)
                    item.name = dock.name
                    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                } label: {
                    Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .controlSize(.large)
            }
            .padding()
        }
    }
}
