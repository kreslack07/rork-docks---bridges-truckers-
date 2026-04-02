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
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .sensoryFeedback(.impact, trigger: viewModel.isFavourite(dock.id))
                }

                HStack(spacing: 8) {
                    Label(dock.dockType.label, systemImage: "arrow.left.arrow.right")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.accent.opacity(0.12), in: Capsule())

                    Label(dock.businessCategory.label, systemImage: dock.businessCategory.icon)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.tertiarySystemFill), in: Capsule())

                    if dock.isOffRoad {
                        Label("Off-Road", systemImage: "road.lanes.curved.right")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.accent.opacity(0.12), in: Capsule())
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    detailRow(icon: "mappin", text: "\(dock.city), \(dock.state)")

                    Button {
                        copyToClipboard(dock.address)
                    } label: {
                        detailRow(icon: "location", text: dock.address)
                    }
                    .tint(.primary)
                    .contextMenu {
                        Button {
                            copyToClipboard(dock.address)
                        } label: {
                            Label("Copy Address", systemImage: "doc.on.doc")
                        }
                    }

                    if let hours = dock.operatingHours {
                        detailRow(icon: "clock", text: hours)
                    }

                    if let phone = dock.phone {
                        Button {
                            if let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "phone.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 20)
                                Text(phone)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                }

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
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                            Text("Access Notes")
                                .font(.subheadline.bold())
                        }
                        Text(dock.accessNotes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(AppTheme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }

                HStack(spacing: 10) {
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

                    ShareLink(
                        item: dockShareText,
                        subject: Text(dock.name),
                        message: Text("Dock info from Docks & Bridges")
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

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    private var dockShareText: String {
        var text = "\(dock.name)\n\(dock.business)\n\(dock.address), \(dock.city) \(dock.state)"
        if let hours = dock.operatingHours { text += "\nHours: \(hours)" }
        if let phone = dock.phone { text += "\nPhone: \(phone)" }
        if !dock.accessNotes.isEmpty { text += "\nAccess: \(dock.accessNotes)" }
        text += "\n— Docks & Bridges Trucker"
        return text
    }
}
