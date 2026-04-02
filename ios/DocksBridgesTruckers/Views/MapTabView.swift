import SwiftUI
import MapKit
import CoreLocation

struct MapTabView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(LocationService.self) private var locationService
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -28.0, longitude: 134.0),
        span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
    ))
    @State private var selectedDock: Dock?
    @State private var selectedHazard: Hazard?
    @State private var showFilterMenu: Bool = false

    private var isLocationDenied: Bool {
        locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted
    }

    private var nonRouteHazards: [Hazard] {
        let routeIDs = Set(viewModel.activeRouteHazards.map(\.id))
        return viewModel.filteredHazards.filter { !routeIDs.contains($0.id) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                if let route = viewModel.activeRoute {
                    MapPolyline(route.polyline)
                        .stroke(AppTheme.accent, lineWidth: 5)
                }

                ForEach(viewModel.activeRouteHazards) { hazard in
                    Annotation(hazard.name, coordinate: hazard.coordinate) {
                        Button {
                            selectedHazard = hazard
                            selectedDock = nil
                        } label: {
                            HazardAnnotationView(hazard: hazard, status: viewModel.hazardStatus(hazard))
                        }
                    }
                }

                ForEach(viewModel.docks) { dock in
                    Annotation(dock.name, coordinate: dock.coordinate) {
                        Button {
                            selectedDock = dock
                            selectedHazard = nil
                        } label: {
                            DockAnnotationView(dock: dock)
                        }
                    }
                }

                ForEach(nonRouteHazards) { hazard in
                    Annotation(hazard.name, coordinate: hazard.coordinate) {
                        Button {
                            selectedHazard = hazard
                            selectedDock = nil
                        } label: {
                            HazardAnnotationView(hazard: hazard, status: viewModel.hazardStatus(hazard))
                        }
                    }
                }

                UserAnnotation()
            }
            .mapStyle(.standard)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }

            mapOverlay

            if isLocationDenied {
                VStack {
                    Spacer()
                    locationDeniedBanner
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedDock?.id)
        .sensoryFeedback(.selection, trigger: selectedHazard?.id)
        .sheet(item: $selectedDock) { dock in
            DockDetailSheet(dock: dock)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .onAppear {
            locationService.requestWhenInUseAuthorization()
        }
        .sheet(item: $selectedHazard) { hazard in
            HazardDetailSheet(hazard: hazard)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
    }

    private var locationDeniedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Location Access Disabled")
                    .font(.caption.bold())
                Text("Enable location in Settings to see your position on the map.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption.bold())
            .foregroundStyle(AppTheme.accent)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var mapOverlay: some View {
        VStack {
            HStack {
                if viewModel.hazardFilter != .all {
                    Text(viewModel.hazardFilter.label)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.accent, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                Button {
                    showFilterMenu = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.thickMaterial, in: Circle())
                }
                .confirmationDialog("Filter Hazards", isPresented: $showFilterMenu) {
                    ForEach(HazardFilter.allCases, id: \.self) { filter in
                        Button(filter.label) {
                            viewModel.hazardFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .animation(.easeInOut(duration: 0.2), value: viewModel.hazardFilter)
            Spacer()
        }
    }
}

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
