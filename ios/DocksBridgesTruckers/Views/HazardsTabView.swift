import SwiftUI

struct HazardsTabView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var searchText: String = ""
    @State private var selectedHazard: Hazard?

    var body: some View {
        NavigationStack {
            List {
                truckInfoSection

                Section {
                    ForEach(filteredHazards) { hazard in
                        Button {
                            selectedHazard = hazard
                        } label: {
                            HazardRowView(hazard: hazard, status: viewModel.hazardStatus(hazard))
                        }
                        .tint(.primary)
                        .swipeActions(edge: .trailing) {
                            Button {
                                withAnimation {
                                    viewModel.toggleHazardFavourite(hazard.id)
                                }
                            } label: {
                                Label(
                                    viewModel.isHazardFavourite(hazard.id) ? "Unsave" : "Save",
                                    systemImage: viewModel.isHazardFavourite(hazard.id) ? "bookmark.slash" : "bookmark.fill"
                                )
                            }
                            .tint(AppTheme.accent)
                        }
                        .accessibilityLabel("\(hazard.name), \(hazard.type.label), \(viewModel.hazardStatus(hazard).label)")
                    }
                } header: {
                    Text("\(filteredHazards.count) hazards")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Hazards")
            .refreshable {
                await viewModel.refreshData()
            }
            .searchable(text: $searchText, prompt: "Search hazards, roads, cities...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(HazardFilter.allCases, id: \.self) { filter in
                            Button {
                                viewModel.hazardFilter = filter
                            } label: {
                                if viewModel.hazardFilter == filter {
                                    Label(filter.label, systemImage: "checkmark")
                                } else {
                                    Text(filter.label)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .symbolVariant(viewModel.hazardFilter != .all ? .fill : .none)
                    }
                }
            }
            .overlay {
                if filteredHazards.isEmpty {
                    if !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ContentUnavailableView(
                            "No Hazards Found",
                            systemImage: "exclamationmark.triangle",
                            description: Text("No \(viewModel.hazardFilter.label.lowercased()) hazards in the database.")
                        )
                    }
                }
            }
            .sheet(item: $selectedHazard) { hazard in
                HazardDetailSheet(hazard: hazard)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
            }
        }
    }

    private var filteredHazards: [Hazard] {
        let base = viewModel.filteredHazards
        if searchText.isEmpty { return base }
        return base.filter {
            $0.name.localizedStandardContains(searchText) ||
            $0.road.localizedStandardContains(searchText) ||
            $0.city.localizedStandardContains(searchText) ||
            $0.state.localizedStandardContains(searchText)
        }
    }

    private var truckInfoSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: viewModel.truckProfile.type.icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.cardGradient, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.truckProfile.type.label)
                        .font(.subheadline.bold())
                    Text("Height: \(String(format: "%.1fm", viewModel.truckProfile.height)) · Weight: \(String(format: "%.1ft", viewModel.truckProfile.weight))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if viewModel.blockedCount > 0 {
                        HStack(spacing: 3) {
                            Circle().fill(.red).frame(width: 6, height: 6)
                            Text("\(viewModel.blockedCount) blocked")
                                .font(.caption2.bold())
                                .foregroundStyle(.red)
                        }
                    }
                    if viewModel.tightCount > 0 {
                        HStack(spacing: 3) {
                            Circle().fill(AppTheme.accent).frame(width: 6, height: 6)
                            Text("\(viewModel.tightCount) tight")
                                .font(.caption2.bold())
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
            }
        }
    }
}

struct HazardRowView: View {
    let hazard: Hazard
    let status: HazardStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: hazard.type.icon)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(status.color.gradient, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(hazard.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(hazard.road + " · " + hazard.city + ", " + hazard.state)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("Verified: \(hazard.lastVerified)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if hazard.type == .weight_limit, let limit = hazard.weightLimit {
                    Text(String(format: "%.0ft", limit))
                        .font(.title3.bold())
                        .foregroundStyle(status.color)
                } else {
                    Text(String(format: "%.1fm", hazard.clearanceHeight))
                        .font(.title3.bold())
                        .foregroundStyle(status.color)
                }

                HStack(spacing: 3) {
                    Image(systemName: status.icon)
                        .font(.system(size: 8))
                    Text(status.label)
                        .font(.system(size: 9, weight: .heavy))
                }
                .foregroundStyle(status.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(status.color.opacity(0.12), in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}
