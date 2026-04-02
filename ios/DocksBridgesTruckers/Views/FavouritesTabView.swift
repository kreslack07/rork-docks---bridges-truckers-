import SwiftUI

struct FavouritesTabView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedDock: Dock?
    @State private var selectedHazard: Hazard?
    @State private var filterMode: FavouriteFilter = .all

    private var filteredDocks: [Dock] {
        guard filterMode == .all || filterMode == .docks else { return [] }
        return viewModel.favouriteDocks
    }

    private var filteredHazards: [Hazard] {
        guard filterMode == .all || filterMode == .hazards else { return [] }
        return viewModel.favouriteHazards
    }

    private var totalCount: Int {
        viewModel.favouriteDocks.count + viewModel.favouriteHazards.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if totalCount == 0 {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            filterBar
                            if !filteredDocks.isEmpty {
                                docksSection
                            }
                            if !filteredHazards.isEmpty {
                                hazardsSection
                            }
                            if filteredDocks.isEmpty && filteredHazards.isEmpty {
                                ContentUnavailableView(
                                    "No \(filterMode.label) Saved",
                                    systemImage: "bookmark.slash",
                                    description: Text("Tap the bookmark icon on any \(filterMode == .docks ? "dock" : "hazard") to save it here.")
                                )
                                .padding(.top, 40)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Favourites")
            .sheet(item: $selectedDock) { dock in
                DockDetailSheet(dock: dock)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
            }
            .sheet(item: $selectedHazard) { hazard in
                HazardDetailSheet(hazard: hazard)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.accent.opacity(0.4))

            Text("No Favourites Yet")
                .font(.title2.bold())

            Text("Save docks and hazards you visit frequently for quick access. Tap the bookmark icon on any dock or hazard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(FavouriteFilter.allCases, id: \.self) { filter in
                let count: Int = switch filter {
                case .all: totalCount
                case .docks: viewModel.favouriteDocks.count
                case .hazards: viewModel.favouriteHazards.count
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        filterMode = filter
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(filter.label)
                            .font(.caption.bold())
                        Text("\(count)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                filterMode == filter ? AppTheme.navy.opacity(0.3) : Color(.tertiarySystemFill),
                                in: Capsule()
                            )
                    }
                    .foregroundStyle(filterMode == filter ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        filterMode == filter ? AppTheme.accent : Color(.secondarySystemGroupedBackground),
                        in: Capsule()
                    )
                }
                .sensoryFeedback(.selection, trigger: filterMode)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    private var docksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(AppTheme.accent)
                Text("Docks (\(filteredDocks.count))")
                    .font(.subheadline.bold())
            }

            ForEach(filteredDocks) { dock in
                Button {
                    selectedDock = dock
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: dock.businessCategory.icon)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(dock.name)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("\(dock.business) · \(dock.city), \(dock.state)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                viewModel.toggleFavourite(dock.id)
                            }
                        } label: {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.isFavourite(dock.id))
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .tint(.primary)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = "\(dock.name), \(dock.address), \(dock.city) \(dock.state)"
                    } label: {
                        Label("Copy Address", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        withAnimation(.spring(duration: 0.3)) {
                            viewModel.toggleFavourite(dock.id)
                        }
                    } label: {
                        Label("Remove Favourite", systemImage: "bookmark.slash")
                    }
                }
            }
        }
    }

    private var hazardsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Hazards (\(filteredHazards.count))")
                    .font(.subheadline.bold())
            }

            ForEach(filteredHazards) { hazard in
                let status = viewModel.hazardStatus(hazard)
                Button {
                    selectedHazard = hazard
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: hazard.type.icon)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(status.color, in: RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(hazard.name)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("\(hazard.road) · \(hazard.city), \(hazard.state)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if hazard.type == .weight_limit, let limit = hazard.weightLimit {
                                Text(String(format: "%.0ft", limit))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(status.color)
                            } else {
                                Text(String(format: "%.1fm", hazard.clearanceHeight))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(status.color)
                            }

                            Button {
                                withAnimation(.spring(duration: 0.3)) {
                                    viewModel.toggleHazardFavourite(hazard.id)
                                }
                            } label: {
                                Image(systemName: "bookmark.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.isHazardFavourite(hazard.id))
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .tint(.primary)
                .contextMenu {
                    Button(role: .destructive) {
                        withAnimation(.spring(duration: 0.3)) {
                            viewModel.toggleHazardFavourite(hazard.id)
                        }
                    } label: {
                        Label("Remove Favourite", systemImage: "bookmark.slash")
                    }
                }
            }
        }
    }
}

nonisolated enum FavouriteFilter: CaseIterable, Sendable {
    case all, docks, hazards

    var label: String {
        switch self {
        case .all: "All"
        case .docks: "Docks"
        case .hazards: "Hazards"
        }
    }
}
