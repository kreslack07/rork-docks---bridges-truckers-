import SwiftUI
import MapKit
import CoreLocation

private nonisolated struct IdentifiableMapItem: Identifiable, Sendable {
    let id: String
    nonisolated(unsafe) let mapItem: MKMapItem

    init(mapItem: MKMapItem) {
        self.mapItem = mapItem
        let coord = mapItem.placemark.coordinate
        self.id = "\(mapItem.name ?? "")_\(coord.latitude)_\(coord.longitude)"
    }
}

struct RouteTabView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(LocationService.self) private var locationService
    @Environment(NavigationService.self) private var navigationService
    @Environment(SearchCompleterService.self) private var searchCompleter
    @Environment(NearbyPlacesService.self) private var nearbyPlaces

    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -28.0, longitude: 134.0),
        span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
    ))
    @State private var destination: String = ""
    @State private var searchResults: [IdentifiableMapItem] = []
    @State private var selectedDestination: MKMapItem?
    @State private var isSearching: Bool = false
    @State private var routeResult: MKRoute?
    @State private var isCalculating: Bool = false
    @State private var hazardsOnRoute: [Hazard] = []
    @State private var searchError: String?
    @State private var routeError: String?
    @State private var selectedHazard: Hazard?
    @State private var selectedDock: Dock?
    @State private var showNavigation: Bool = false
    @State private var sheetDetent: PresentationDetent = .fraction(0.12)
    @State private var showFilterMenu: Bool = false
    @State private var showNearbyPlaces: Bool = false
    @State private var selectedNearbyPlace: NearbyPlace?
    @State private var isTyping: Bool = false
    @State private var searchTask: Task<Void, Never>?
    @State private var hasCenteredOnUser: Bool = false

    private var nonRouteHazards: [Hazard] {
        let routeIDs = Set(viewModel.activeRouteHazards.map(\.id))
        return viewModel.filteredHazards.filter { !routeIDs.contains($0.id) }
    }

    private var currentRegion: MKCoordinateRegion {
        let center = locationService.userLocation?.coordinate ?? CLLocationCoordinate2D(latitude: -28.0, longitude: 134.0)
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2))
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                truckInfoBar
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                Spacer()
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    mapButtons
                        .padding(.trailing, 12)
                        .padding(.bottom, 12)
                }
            }
        }
        .sheet(isPresented: .constant(true)) {
            dockSheet
                .presentationDetents([.fraction(0.12), .fraction(0.4), .large], selection: $sheetDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
                .presentationCornerRadius(20)
                .presentationContentInteraction(.scrolls)
                .interactiveDismissDisabled()
        }
        .sheet(item: $selectedHazard) { hazard in
            HazardDetailSheet(hazard: hazard)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $selectedDock) { dock in
            DockDetailSheet(dock: dock)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .fullScreenCover(isPresented: $showNavigation) {
            NavigationMapView()
        }
        .onAppear {
            locationService.requestWhenInUseAuthorization()
            if let loc = locationService.userLocation {
                position = .region(MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                ))
                hasCenteredOnUser = true
            }
            searchCompleter.updateSearchRegion(currentRegion)
        }
        .onChange(of: locationService.hasReceivedFirstLocation) { _, received in
            guard received, !hasCenteredOnUser, let loc = locationService.userLocation else { return }
            hasCenteredOnUser = true
            withAnimation(.easeInOut(duration: 0.6)) {
                position = .region(MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                ))
            }
        }
        .onChange(of: destination) { _, newValue in
            if isTyping {
                searchCompleter.updateSearchRegion(currentRegion)
                searchCompleter.search(newValue)
                if !newValue.isEmpty && selectedDestination == nil {
                    sheetDetent = .fraction(0.4)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedDestination?.name)
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(position: $position) {
            if let route = routeResult {
                MapPolyline(route.polyline)
                    .stroke(.blue.opacity(0.3), lineWidth: 12)
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 5)
            } else if let activeRoute = viewModel.activeRoute {
                MapPolyline(activeRoute.polyline)
                    .stroke(AppTheme.accent, lineWidth: 5)
            }

            ForEach(hazardsOnRoute.isEmpty ? viewModel.activeRouteHazards : hazardsOnRoute) { hazard in
                Annotation(hazard.name, coordinate: hazard.coordinate) {
                    Button { selectedHazard = hazard } label: {
                        HazardAnnotationView(hazard: hazard, status: viewModel.hazardStatus(hazard))
                    }
                }
            }

            ForEach(nonRouteHazards) { hazard in
                Annotation(hazard.name, coordinate: hazard.coordinate) {
                    Button { selectedHazard = hazard } label: {
                        HazardAnnotationView(hazard: hazard, status: viewModel.hazardStatus(hazard))
                    }
                }
            }

            ForEach(viewModel.docks) { dock in
                Annotation(dock.name, coordinate: dock.coordinate) {
                    Button { selectedDock = dock } label: {
                        DockAnnotationView(dock: dock)
                    }
                }
            }

            if let dest = selectedDestination {
                Annotation("Destination", coordinate: dest.placemark.coordinate) {
                    Image(systemName: "flag.checkered.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                }
            }

            ForEach(nearbyPlaces.places) { place in
                Annotation(place.name, coordinate: place.coordinate) {
                    Button {
                        selectedNearbyPlace = place
                    } label: {
                        NearbyPlaceAnnotationView(place: place)
                    }
                }
            }

            UserAnnotation()
        }
        .mapStyle(.standard)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    // MARK: - Truck Info Bar

    private var truckInfoBar: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.truckProfile.type.icon)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(AppTheme.cardGradient, in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 6) {
                Label(String(format: "%.1fm", viewModel.truckProfile.height), systemImage: "arrow.up.and.down")
                Label(String(format: "%.1ft", viewModel.truckProfile.weight), systemImage: "scalemass")
                Label(String(format: "%.1fm", viewModel.truckProfile.length), systemImage: "arrow.left.and.right")
            }
            .font(.caption2.bold())
            .foregroundStyle(.primary)

            Spacer()

            if viewModel.blockedCount > 0 {
                HStack(spacing: 3) {
                    Circle().fill(.red).frame(width: 6, height: 6)
                    Text("\(viewModel.blockedCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.red)
                }
            }

            if viewModel.tightCount > 0 {
                HStack(spacing: 3) {
                    Circle().fill(AppTheme.accent).frame(width: 6, height: 6)
                    Text("\(viewModel.tightCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }

    // MARK: - Map Buttons

    private var mapButtons: some View {
        VStack(spacing: 8) {
            Button {
                if let loc = locationService.userLocation {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        position = .region(MKCoordinateRegion(
                            center: loc.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        ))
                    }
                }
            } label: {
                Image(systemName: "location.fill")
                    .font(.body.bold())
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(.thickMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }

            Button {
                showFilterMenu = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.body.bold())
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.thickMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
            .confirmationDialog("Filter Hazards", isPresented: $showFilterMenu) {
                ForEach(HazardFilter.allCases, id: \.self) { filter in
                    Button(filter.label) {
                        viewModel.hazardFilter = filter
                    }
                }
            }
        }
    }

    // MARK: - Dock Sheet

    private var dockSheet: some View {
        ScrollView {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if let error = searchError {
                    errorBanner(message: error, icon: "magnifyingglass")
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                }
                if let error = routeError {
                    errorBanner(message: error, icon: "arrow.triangle.turn.up.right.diamond")
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                }

                if !destination.isEmpty && !searchCompleter.results.isEmpty && selectedDestination == nil && searchResults.isEmpty {
                    RouteAutocompleteListView(
                        completions: searchCompleter.results,
                        onSelect: { selectCompletion($0) }
                    )
                    .padding(.top, 8)
                }

                if !searchResults.isEmpty && selectedDestination == nil {
                    searchResultsList
                        .padding(.top, 12)
                }

                if let selected = selectedDestination {
                    destinationCard(selected)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                if let place = selectedNearbyPlace {
                    nearbyPlaceCard(place)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                if isCalculating {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else if let route = routeResult {
                    RouteInfoCardView(
                        route: route,
                        hazardCount: hazardsOnRoute.count,
                        onStartNavigation: {
                            navigationService.startNavigation(route: route, hazards: hazardsOnRoute)
                            showNavigation = true
                        },
                        routeSummaryText: routeSummaryText(route)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                if !hazardsOnRoute.isEmpty {
                    RouteHazardListView(
                        hazards: hazardsOnRoute,
                        statusProvider: { viewModel.hazardStatus($0) },
                        onSelect: { selectedHazard = $0 }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }

                if selectedDestination == nil && searchResults.isEmpty && routeResult == nil && !isSearching && destination.isEmpty {
                    nearbyDiscoverySection
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    quickActions
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }

                locationPermissionBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer(minLength: 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.body)

                TextField("Where to?", text: $destination, onEditingChanged: { editing in
                    isTyping = editing
                    if editing && !destination.isEmpty {
                        sheetDetent = .fraction(0.4)
                    }
                })
                .font(.body)
                .textContentType(.fullStreetAddress)
                .onSubmit {
                    isTyping = false
                    searchCompleter.clear()
                    performSearch()
                }

                if isSearching || searchCompleter.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                if !destination.isEmpty {
                    Button {
                        clearAll()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

            vehicleDimensionsBar
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @State private var showVehicleEditor: Bool = false

    private var vehicleDimensionsBar: some View {
        Button {
            showVehicleEditor = true
        } label: {
            HStack(spacing: 0) {
                dimensionPill(icon: "arrow.up.and.down", value: String(format: "%.1fm", viewModel.truckProfile.height), label: "H")
                Divider().frame(height: 20)
                dimensionPill(icon: "scalemass", value: String(format: "%.1ft", viewModel.truckProfile.weight), label: "W")
                Divider().frame(height: 20)
                dimensionPill(icon: "arrow.left.and.right", value: String(format: "%.1fm", viewModel.truckProfile.length), label: "L")
            }
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .sheet(isPresented: $showVehicleEditor) {
            VehicleDimensionsSheet()
                .environment(viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private func dimensionPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.accent)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        isTyping = false
        destination = completion.title
        searchCompleter.clear()
        sheetDetent = .fraction(0.4)
        Task {
            if let mapItem = await searchCompleter.resolveCompletion(completion) {
                selectDestination(mapItem)
            } else {
                performSearch()
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        VStack(spacing: 2) {
            ForEach(searchResults) { result in
                Button {
                    selectDestination(result.mapItem)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(AppTheme.accent)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.mapItem.name ?? "Unknown")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            if let subtitle = result.mapItem.placemark.title {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.title3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // MARK: - Destination Card

    private func destinationCard(_ item: MKMapItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 40, height: 40)
                .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

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

            if routeResult != nil {
                Button {
                    navigationService.startNavigation(route: routeResult!, hazards: hazardsOnRoute)
                    showNavigation = true
                } label: {
                    Image(systemName: "location.fill")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.blue, in: Circle())
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Nearby Place Card

    private func nearbyPlaceCard(_ place: NearbyPlace) -> some View {
        HStack(spacing: 12) {
            Image(systemName: place.category.icon)
                .font(.title3)
                .foregroundStyle(place.category.color)
                .frame(width: 40, height: 40)
                .background(place.category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.subheadline.bold())
                if let address = place.address {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let dist = place.distance {
                    Text(formatDistance(dist))
                        .font(.caption2.bold())
                        .foregroundStyle(place.category.color)
                }
            }

            Spacer()

            Button {
                navigateToNearbyPlace(place)
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.body.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.blue, in: Circle())
            }

            Button {
                selectedNearbyPlace = nil
                nearbyPlaces.clear()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Nearby Discovery

    private var nearbyDiscoverySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "location.magnifyingglass")
                    .foregroundStyle(AppTheme.accent)
                Text("Find Nearby")
                    .font(.subheadline.bold())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(NearbyCategory.allCases, id: \.self) { category in
                        Button {
                            searchNearbyCategory(category)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.caption)
                                    .foregroundStyle(nearbyPlaces.selectedCategory == category && showNearbyPlaces ? .white : category.color)
                                Text(category.label)
                                    .font(.caption.bold())
                                    .foregroundStyle(nearbyPlaces.selectedCategory == category && showNearbyPlaces ? .white : .primary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                nearbyPlaces.selectedCategory == category && showNearbyPlaces
                                    ? AnyShapeStyle(category.color)
                                    : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                                in: Capsule()
                            )
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
            .contentMargins(.horizontal, 0)

            if nearbyPlaces.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 8)
                    Spacer()
                }
            }

            if let error = nearbyPlaces.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if showNearbyPlaces && !nearbyPlaces.places.isEmpty {
                VStack(spacing: 6) {
                    ForEach(nearbyPlaces.places.prefix(6)) { place in
                        Button {
                            selectedNearbyPlace = place
                            withAnimation(.easeInOut(duration: 0.5)) {
                                position = .region(MKCoordinateRegion(
                                    center: place.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                ))
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: place.category.icon)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(place.category.color, in: RoundedRectangle(cornerRadius: 7))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(place.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    if let address = place.address {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                if let dist = place.distance {
                                    Text(formatDistance(dist))
                                        .font(.caption.bold())
                                        .foregroundStyle(place.category.color)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(10)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .tint(.primary)
                    }
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.favouriteDocks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(AppTheme.accent)
                        Text("Saved Docks")
                            .font(.subheadline.bold())
                    }

                    ForEach(viewModel.favouriteDocks.prefix(4)) { dock in
                        Button {
                            destination = dock.address + ", " + dock.city
                            isTyping = false
                            performSearch()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: dock.businessCategory.icon)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 7))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(dock.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Text("\(dock.city), \(dock.state)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "arrow.right.circle")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(10)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .tint(.primary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Search")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    quickChip("Bridges", icon: "road.lanes", query: "Bridge")
                    quickChip("Hotels", icon: "bed.double.fill", query: "Hotel")
                    quickChip("Ports", icon: "ferry.fill", query: "Port")
                    quickChip("Fuel", icon: "fuelpump.fill", query: "Fuel")
                }
            }
        }
    }

    private func quickChip(_ label: String, icon: String, query: String) -> some View {
        Button {
            destination = query
            isTyping = false
            performSearch()
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

    // MARK: - Location Permission Banner

    @ViewBuilder
    private var locationPermissionBanner: some View {
        if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
            HStack(spacing: 8) {
                Image(systemName: "location.slash.fill")
                    .foregroundStyle(AppTheme.accent)
                Text("Location access needed for routing.")
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

    // MARK: - Error Banner

    private func errorBanner(message: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func clearAll() {
        searchTask?.cancel()
        searchTask = nil
        destination = ""
        searchResults = []
        selectedDestination = nil
        routeResult = nil
        hazardsOnRoute = []
        searchError = nil
        routeError = nil
        isSearching = false
        isCalculating = false
        selectedNearbyPlace = nil
        nearbyPlaces.clear()
        showNearbyPlaces = false
        searchCompleter.clear()
        viewModel.clearRoute()
        sheetDetent = .fraction(0.12)
    }

    private func selectDestination(_ item: MKMapItem) {
        selectedDestination = item
        selectedNearbyPlace = nil
        searchResults = []
        searchCompleter.clear()

        let coord = item.placemark.coordinate
        withAnimation(.easeInOut(duration: 0.5)) {
            position = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ))
        }

        calculateRoute(to: item)
    }

    private func performSearch() {
        guard !destination.isEmpty else { return }
        searchTask?.cancel()
        isSearching = true
        searchError = nil
        searchCompleter.clear()
        sheetDetent = .fraction(0.4)

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = destination
        let searchCenter = locationService.userLocation?.coordinate ?? CLLocationCoordinate2D(latitude: -28.0, longitude: 134.0)
        request.region = MKCoordinateRegion(
            center: searchCenter,
            span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
        )
        let search = MKLocalSearch(request: request)
        searchTask = Task {
            do {
                let response = try await search.start()
                guard !Task.isCancelled else { return }
                isSearching = false
                searchResults = response.mapItems.map { IdentifiableMapItem(mapItem: $0) }
                if searchResults.isEmpty {
                    searchError = "No results found. Try a different search term."
                }
            } catch {
                guard !Task.isCancelled else { return }
                isSearching = false
                searchResults = []
                searchError = "Search failed. Check your connection and try again."
            }
        }
    }

    private func searchNearbyCategory(_ category: NearbyCategory) {
        showNearbyPlaces = true
        sheetDetent = .fraction(0.4)
        Task {
            await nearbyPlaces.searchNearby(
                category: category,
                region: currentRegion,
                userLocation: locationService.userLocation
            )
        }
    }

    private func navigateToNearbyPlace(_ place: NearbyPlace) {
        let placemark = MKPlacemark(coordinate: place.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = place.name
        selectDestination(mapItem)
    }

    private func calculateRoute(to item: MKMapItem) {
        let status = locationService.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            routeError = status == .denied || status == .restricted
                ? "Location access is denied. Enable it in Settings to calculate routes."
                : "Location permission is needed to calculate a route."
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
                    withAnimation(.easeInOut(duration: 0.6)) {
                        position = .rect(route.polyline.boundingMapRect.insetBy(dx: -route.polyline.boundingMapRect.width * 0.2, dy: -route.polyline.boundingMapRect.height * 0.2))
                    }
                    sheetDetent = .fraction(0.4)
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
            let thresholdDeg = 50_000.0 / 111_000.0
            hazardsOnRoute = viewModel.hazards.filter { hazard in
                let dLat = abs(hazard.latitude - destCoord.latitude)
                let dLon = abs(hazard.longitude - destCoord.longitude)
                guard dLat < thresholdDeg, dLon < thresholdDeg else { return false }
                let hazardLoc = CLLocation(latitude: hazard.latitude, longitude: hazard.longitude)
                let destLoc = CLLocation(latitude: destCoord.latitude, longitude: destCoord.longitude)
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

    private func formatDuration(_ seconds: TimeInterval) -> String {
        Formatters.duration(seconds)
    }

    private func formatDistance(_ meters: Double) -> String {
        Formatters.distance(meters)
    }
}

