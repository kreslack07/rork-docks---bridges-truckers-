import SwiftUI

struct SearchView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var searchText: String = ""
    @State private var selectedDock: Dock?
    @State private var selectedHazard: Hazard?
    @State private var searchScope: SearchScope = .all

    private var matchingDocks: [Dock] {
        guard !searchText.isEmpty else { return [] }
        return viewModel.docks.filter {
            $0.name.localizedStandardContains(searchText) ||
            $0.business.localizedStandardContains(searchText) ||
            $0.address.localizedStandardContains(searchText) ||
            $0.city.localizedStandardContains(searchText) ||
            $0.state.localizedStandardContains(searchText) ||
            $0.businessCategory.label.localizedStandardContains(searchText)
        }
    }

    private var matchingHazards: [Hazard] {
        guard !searchText.isEmpty else { return [] }
        return viewModel.hazards.filter {
            $0.name.localizedStandardContains(searchText) ||
            $0.road.localizedStandardContains(searchText) ||
            $0.city.localizedStandardContains(searchText) ||
            $0.state.localizedStandardContains(searchText) ||
            $0.type.label.localizedStandardContains(searchText)
        }
    }

    private var scopedDocks: [Dock] {
        searchScope == .hazards ? [] : matchingDocks
    }

    private var scopedHazards: [Hazard] {
        searchScope == .docks ? [] : matchingHazards
    }

    private var hasResults: Bool {
        !scopedDocks.isEmpty || !scopedHazards.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    recentAndSuggestions
                } else if !hasResults {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    resultsList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Docks, hazards, cities, roads...")
            .searchScopes($searchScope) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    Text(scope.label).tag(scope)
                }
            }
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

    private var recentAndSuggestions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                quickSearchSection

                if !viewModel.favouriteDocks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(AppTheme.accent)
                            Text("Saved Docks")
                                .font(.subheadline.bold())
                        }

                        ForEach(viewModel.favouriteDocks.prefix(5)) { dock in
                            Button {
                                selectedDock = dock
                            } label: {
                                suggestionRow(
                                    icon: dock.businessCategory.icon,
                                    iconColor: AppTheme.accent,
                                    title: dock.name,
                                    subtitle: "\(dock.city), \(dock.state)"
                                )
                            }
                            .tint(.primary)
                        }
                    }
                }

                statsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private var quickSearchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Search")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                quickChip("Bridges", icon: "road.lanes", query: "Bridge")
                quickChip("Wires", icon: "bolt.fill", query: "Wire")
                quickChip("Hotels", icon: "bed.double.fill", query: "Hotel")
                quickChip("Ports", icon: "ferry.fill", query: "Port")
                quickChip("Warehouses", icon: "shippingbox.fill", query: "Warehouse")
                quickChip("Hospitals", icon: "cross.fill", query: "Hospital")
            }
        }
        .padding(.top, 8)
    }

    private func quickChip(_ label: String, icon: String, query: String) -> some View {
        Button {
            searchText = query
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
                Text(label)
                    .font(.caption.bold())
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Database")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                statCard(count: viewModel.docks.count, label: "Docks", icon: "shippingbox.fill", color: AppTheme.accent)
                statCard(count: viewModel.hazards.count, label: "Hazards", icon: "exclamationmark.triangle.fill", color: .red)
            }
        }
    }

    private func statCard(count: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var resultsList: some View {
        List {
            if !scopedDocks.isEmpty {
                Section("Docks (\(scopedDocks.count))") {
                    ForEach(scopedDocks) { dock in
                        Button {
                            selectedDock = dock
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: dock.businessCategory.icon)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dock.name)
                                        .font(.subheadline.bold())
                                    Text("\(dock.business) · \(dock.city), \(dock.state)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if viewModel.isFavourite(dock.id) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
            }

            if !scopedHazards.isEmpty {
                Section("Hazards (\(scopedHazards.count))") {
                    ForEach(scopedHazards) { hazard in
                        let status = viewModel.hazardStatus(hazard)
                        Button {
                            selectedHazard = hazard
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: hazard.type.icon)
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(status.color, in: RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hazard.name)
                                        .font(.subheadline.bold())
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
                                    HStack(spacing: 2) {
                                        Image(systemName: status.icon)
                                            .font(.system(size: 7))
                                        Text(status.label)
                                            .font(.system(size: 8, weight: .heavy))
                                    }
                                    .foregroundStyle(status.color)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func suggestionRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

nonisolated enum SearchScope: CaseIterable, Sendable {
    case all, docks, hazards

    var label: String {
        switch self {
        case .all: "All"
        case .docks: "Docks"
        case .hazards: "Hazards"
        }
    }
}
