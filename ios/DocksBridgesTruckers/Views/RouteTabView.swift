import SwiftUI
import MapKit

private struct IdentifiableMapItem: Identifiable {
    let id: String
    let mapItem: MKMapItem

    init(mapItem: MKMapItem) {
        self.mapItem = mapItem
        let coord = mapItem.placemark.coordinate
        self.id = "\(mapItem.name ?? "")_\(coord.latitude)_\(coord.longitude)"
    }
}

struct RouteTabView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(LocationService.self) private var locationService
    @State private var destination: String = ""
    @State private var searchResults: [IdentifiableMapItem] = []
    @State private var selectedDestination: MKMapItem?
    @State private var isSearching: Bool = false
    @State private var routeResult: MKRoute?
    @State private var isCalculating: Bool = false
    @State private var hazardsOnRoute: [Hazard] = []
    @State private var searchError: String?
    @State private var routeError: String?
    @State private var cachedNearbyDocks: [Dock] = []
    @State private var selectedHazard: Hazard?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    truckCard
                    searchSection
                    if !searchResults.isEmpty && selectedDestination == nil {
                        searchResultsList
                    }
                    if let selected = selectedDestination {
                        destinationCard(selected)
                    }
                    if isCalculating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else if let route = routeResult {
                        routeInfoCard(route)
                    }
                    if let error = searchError {
                        errorBanner(message: error, icon: "magnifyingglass")
                    }
                    if let error = routeError {
                        errorBanner(message: error, icon: "arrow.triangle.turn.up.right.diamond")
                    }
                    if !hazardsOnRoute.isEmpty {
                        hazardsOnRouteSection
                    }
                    if selectedDestination != nil || routeResult != nil {
                        nearbyDocksSection
                    }

                    if selectedDestination == nil && searchResults.isEmpty && routeResult == nil && !isSearching {
                        routeEmptyState
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Route")
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .onAppear { updateNearbyDocks() }
            .onChange(of: selectedDestination) { _, _ in updateNearbyDocks() }
            .sensoryFeedback(.selection, trigger: selectedDestination?.name)
            .sheet(item: $selectedHazard) { hazard in
                HazardDetailSheet(hazard: hazard)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
            }
        }
    }

    private var routeEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.accent.opacity(0.3))

            Text("Plan Your Route")
                .font(.title3.bold())

            Text("Search for a destination to check hazards along the way and find nearby docks.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private var truckCard: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.truckProfile.type.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(AppTheme.cardGradient, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.truckProfile.type.label)
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    Label(String(format: "%.1fm", viewModel.truckProfile.height), systemImage: "arrow.up.and.down")
                    Label(String(format: "%.1ft", viewModel.truckProfile.weight), systemImage: "scalemass")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()

            if viewModel.blockedCount > 0 {
                HStack(spacing: 3) {
                    Circle().fill(.red).frame(width: 6, height: 6)
                    Text("\(viewModel.blockedCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Where to?")
                .font(.headline)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Enter destination", text: $destination)
                    .textContentType(.fullStreetAddress)
                    .onSubmit { performSearch() }
                if !destination.isEmpty {
                    Button {
                        destination = ""
                        searchResults = []
                        selectedDestination = nil
                        routeResult = nil
                        hazardsOnRoute = []
                        searchError = nil
                        routeError = nil
                        viewModel.clearRoute()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

            Button {
                performSearch()
            } label: {
                Label(isSearching ? "Searching..." : "Search", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .disabled(destination.isEmpty || isSearching)

            if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
                HStack(spacing: 8) {
                    Image(systemName: "location.slash.fill")
                        .foregroundStyle(AppTheme.accent)
                    Text("Location access needed for route calculation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accent)
                }
                .padding(10)
                .background(AppTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            } else if locationService.authorizationStatus == .notDetermined {
                Button {
                    locationService.requestWhenInUseAuthorization()
                } label: {
                    Label("Enable Location for Routes", systemImage: "location")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accent)
            }
        }
    }

    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Results")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            ForEach(searchResults) { result in
                Button {
                    selectedDestination = result.mapItem
                    searchResults = []
                    calculateRoute(to: result.mapItem)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(AppTheme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(result.mapItem.name ?? "Unknown")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            if let subtitle = result.mapItem.placemark.title {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func destinationCard(_ item: MKMapItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.title3)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name ?? "Destination")
                    .font(.subheadline.bold())
                if let address = item.placemark.title {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Button {
                let mapItem = item
                mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.green, in: Circle())
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func routeInfoCard(_ route: MKRoute) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text(formatDuration(route.expectedTravelTime))
                        .font(.headline.bold())
                    Text("Travel Time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 40)

                VStack(spacing: 4) {
                    Image(systemName: "road.lanes")
                        .foregroundStyle(.secondary)
                    Text(formatDistance(route.distance))
                        .font(.headline.bold())
                    Text("Distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 40)

                VStack(spacing: 4) {
                    Image(systemName: hazardsOnRoute.isEmpty ? "checkmark.shield" : "exclamationmark.triangle")
                        .foregroundStyle(hazardsOnRoute.isEmpty ? .green : .orange)
                    Text("\(hazardsOnRoute.count)")
                        .font(.headline.bold())
                    Text("Hazards")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            ShareLink(
                item: routeSummaryText(route),
                subject: Text("Route Info"),
                message: Text("Route details from Docks & Bridges")
            ) {
                Label("Share Route", systemImage: "square.and.arrow.up")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.accent)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func routeSummaryText(_ route: MKRoute) -> String {
        var text = "Route: \(formatDistance(route.distance)), \(formatDuration(route.expectedTravelTime))"
        if !hazardsOnRoute.isEmpty {
            let blocked = hazardsOnRoute.filter { viewModel.hazardStatus($0) == .blocked }.count
            let tight = hazardsOnRoute.filter { viewModel.hazardStatus($0) == .tight }.count
            text += "\n\(hazardsOnRoute.count) hazards (\(blocked) blocked, \(tight) tight)"
        }
        text += "\nTruck: \(viewModel.truckProfile.type.label), \(String(format: "%.1fm", viewModel.truckProfile.height))"
        text += "\n— Docks & Bridges Trucker"
        return text
    }

    private var hazardsOnRouteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.accent)
                Text("Hazards Near Route")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(hazardsOnRoute.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
            ForEach(hazardsOnRoute) { hazard in
                let status = viewModel.hazardStatus(hazard)
                Button {
                    selectedHazard = hazard
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: hazard.type.icon)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(status.color, in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(hazard.name)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Text(hazard.road)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if hazard.type == .weight_limit, let limit = hazard.weightLimit {
                            Text(String(format: "%.0ft", limit))
                                .font(.subheadline.bold())
                                .foregroundStyle(status.color)
                        } else {
                            Text(String(format: "%.1fm", hazard.clearanceHeight))
                                .font(.subheadline.bold())
                                .foregroundStyle(status.color)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                }
                .tint(.primary)
            }
        }
    }

    private func updateNearbyDocks() {
        guard let dest = selectedDestination else {
            cachedNearbyDocks = Array(viewModel.docks.prefix(5))
            return
        }
        let destLocation = CLLocation(latitude: dest.placemark.coordinate.latitude, longitude: dest.placemark.coordinate.longitude)
        cachedNearbyDocks = viewModel.docks.sorted {
            let loc0 = CLLocation(latitude: $0.latitude, longitude: $0.longitude)
            let loc1 = CLLocation(latitude: $1.latitude, longitude: $1.longitude)
            return loc0.distance(from: destLocation) < loc1.distance(from: destLocation)
        }.prefix(5).map { $0 }
    }

    private var nearbyDocksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(AppTheme.accent)
                Text("Nearby Docks")
                    .font(.subheadline.bold())
            }
            ForEach(cachedNearbyDocks) { dock in
                Button {
                    destination = dock.address + ", " + dock.city
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: dock.businessCategory.icon)
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 28, height: 28)
                            .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(dock.name)
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("\(dock.city), \(dock.state)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func errorBanner(message: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func performSearch() {
        guard !destination.isEmpty else { return }
        isSearching = true
        searchError = nil
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = destination
        let searchCenter = locationService.userLocation?.coordinate ?? CLLocationCoordinate2D(latitude: -28.0, longitude: 134.0)
        request.region = MKCoordinateRegion(
            center: searchCenter,
            span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
        )
        let search = MKLocalSearch(request: request)
        Task {
            do {
                let response = try await search.start()
                isSearching = false
                searchResults = response.mapItems.map { IdentifiableMapItem(mapItem: $0) }
                if searchResults.isEmpty {
                    searchError = "No results found. Try a different search term."
                }
            } catch {
                isSearching = false
                searchResults = []
                searchError = "Search failed. Check your connection and try again."
            }
        }
    }

    private func calculateRoute(to item: MKMapItem) {
        let status = locationService.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            routeError = status == .denied || status == .restricted
                ? "Location access is denied. Enable it in Settings > Privacy > Location Services to calculate routes."
                : "Location permission is needed to calculate a route from your current position."
            if status == .notDetermined {
                locationService.requestWhenInUseAuthorization()
            }
            return
        }

        isCalculating = true
        routeError = nil

        let source: MKMapItem
        if let loc = locationService.userLocation {
            let placemark = MKPlacemark(coordinate: loc.coordinate)
            source = MKMapItem(placemark: placemark)
        } else {
            source = MKMapItem.forCurrentLocation()
        }

        let request = MKDirections.Request()
        request.source = source
        request.destination = item
        request.transportType = .automobile
        let directions = MKDirections(request: request)
        Task {
            do {
                let response = try await directions.calculate()
                isCalculating = false
                routeResult = response.routes.first
                if routeResult == nil {
                    routeError = "No driving route found to this destination."
                }
                findHazardsNearRoute()
                if let route = routeResult {
                    viewModel.setRoute(route, hazards: hazardsOnRoute)
                }
            } catch {
                isCalculating = false
                routeResult = nil
                routeError = "Could not calculate route. Try a different destination."
                hazardsOnRoute = []
            }
        }
    }

    private func findHazardsNearRoute() {
        guard let route = routeResult else {
            guard let dest = selectedDestination else { return }
            let destCoord = dest.placemark.coordinate
            let destLat = destCoord.latitude
            let destLon = destCoord.longitude
            let thresholdDeg = 50_000.0 / 111_000.0
            hazardsOnRoute = viewModel.hazards.filter { hazard in
                let dLat = abs(hazard.latitude - destLat)
                let dLon = abs(hazard.longitude - destLon)
                guard dLat < thresholdDeg, dLon < thresholdDeg else { return false }
                let hazardLoc = CLLocation(latitude: hazard.latitude, longitude: hazard.longitude)
                let destLoc = CLLocation(latitude: destLat, longitude: destLon)
                return hazardLoc.distance(from: destLoc) < 50_000
            }.sorted { viewModel.hazardStatus($0).sortOrder < viewModel.hazardStatus($1).sortOrder }
            return
        }
        let polyline = route.polyline
        let pointCount = polyline.pointCount
        let points = polyline.points()
        let step = max(1, pointCount / 200)
        var sampledCoords: [(lat: Double, lon: Double)] = []
        sampledCoords.reserveCapacity(min(pointCount, 201))
        for i in stride(from: 0, to: pointCount, by: step) {
            let coord = points[i].coordinate
            sampledCoords.append((coord.latitude, coord.longitude))
        }
        if pointCount > 1 {
            let lastCoord = points[pointCount - 1].coordinate
            sampledCoords.append((lastCoord.latitude, lastCoord.longitude))
        }
        let thresholdDeg = 5_000.0 / 111_000.0
        hazardsOnRoute = viewModel.hazards.filter { hazard in
            let hLat = hazard.latitude
            let hLon = hazard.longitude
            for pt in sampledCoords {
                let dLat = abs(hLat - pt.lat)
                let dLon = abs(hLon - pt.lon)
                guard dLat < thresholdDeg, dLon < thresholdDeg else { continue }
                let hazardLoc = CLLocation(latitude: hLat, longitude: hLon)
                let ptLoc = CLLocation(latitude: pt.lat, longitude: pt.lon)
                if hazardLoc.distance(from: ptLoc) < 5_000 { return true }
            }
            return false
        }.sorted { viewModel.hazardStatus($0).sortOrder < viewModel.hazardStatus($1).sortOrder }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func formatDistance(_ meters: Double) -> String {
        let km = meters / 1000
        if km >= 100 { return String(format: "%.0f km", km) }
        return String(format: "%.1f km", km)
    }
}
