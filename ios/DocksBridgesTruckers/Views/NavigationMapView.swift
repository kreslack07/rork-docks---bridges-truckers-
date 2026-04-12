import SwiftUI
import MapKit
import CoreLocation

struct NavigationMapView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(LocationService.self) private var locationService
    @Environment(NavigationService.self) private var navigationService
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showStepsList: Bool = false
    @State private var showHazardAlert: Bool = false
    @State private var alertedHazard: Hazard?
    @State private var isCameraLocked: Bool = true
    @State private var speedKmh: Double = 0
    @State private var isProgrammaticCameraMove: Bool = false

    private let hazardAlertThreshold: CLLocationDistance = 2000

    var body: some View {
        ZStack {
            mapLayer

            VStack(spacing: 0) {
                directionBanner
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                if let hazard = nearestBlockedHazard, let dist = navigationService.nextHazardDistance, dist < hazardAlertThreshold {
                    hazardWarningBanner(hazard: hazard, distance: dist)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                bottomBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
            .animation(.easeInOut(duration: 0.3), value: navigationService.currentStepIndex)

            if navigationService.hasArrived {
                arrivedOverlay
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: locationService.userLocation) { _, newLocation in
            guard let location = newLocation else { return }
            navigationService.updateLocation(location)
            let newSpeed = max(0, location.speed * 3.6)
            if abs(newSpeed - speedKmh) > 1 {
                speedKmh = newSpeed
            }
            if isCameraLocked {
                updateCamera(for: location)
            }
        }
        .onAppear {
            locationService.startNavigationMode()
            isCameraLocked = true
        }
        .onDisappear {
            locationService.stopNavigationMode()
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: navigationService.isNavigating)
        .sensoryFeedback(.success, trigger: navigationService.hasArrived)
        .sheet(isPresented: $showStepsList) {
            stepsListSheet
        }
        .statusBarHidden(true)
    }

    private var mapLayer: some View {
        Map(position: $position, interactionModes: .all) {
            if let route = navigationService.currentRoute {
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 7)

                MapPolyline(route.polyline)
                    .stroke(.cyan.opacity(0.4), lineWidth: 12)
            }

            ForEach(navigationService.upcomingHazards) { hazard in
                let status = viewModel.hazardStatus(hazard)
                Annotation(hazard.name, coordinate: hazard.coordinate) {
                    VStack(spacing: 2) {
                        Image(systemName: hazard.type.icon)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(status.color, in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                        if hazard.type == .weight_limit, let limit = hazard.weightLimit {
                            Text(String(format: "%.0ft", limit))
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(status.color)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.ultraThinMaterial, in: Capsule())
                        } else {
                            Text(String(format: "%.1fm", hazard.clearanceHeight))
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(status.color)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                }
            }

            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {}
        .onMapCameraChange(frequency: .continuous) { _ in
            if !isProgrammaticCameraMove && isCameraLocked {
                isCameraLocked = false
            }
        }
    }

    private var directionBanner: some View {
        VStack(spacing: 0) {
            if let step = navigationService.currentStep {
                HStack(spacing: 14) {
                    Image(systemName: navigationService.maneuverIcon(for: step))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(navigationService.formatDistance(navigationService.distanceToNextStep))
                            .font(.title2.bold())
                            .foregroundStyle(.primary)

                        Text(step.instructions)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(14)

                if let next = navigationService.nextStep {
                    Divider()
                        .padding(.horizontal, 14)

                    HStack(spacing: 10) {
                        Image(systemName: navigationService.maneuverIcon(for: next))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)

                        Text("Then \(next.instructions)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.up")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Navigating...")
                            .font(.title2.bold())
                        Text("Follow the route")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(14)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    private func hazardWarningBanner(hazard: Hazard, distance: CLLocationDistance) -> some View {
        let status = viewModel.hazardStatus(hazard)
        return HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3.bold())
                .foregroundStyle(status == .blocked ? .red : AppTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(status == .blocked ? "BLOCKED AHEAD" : "CAUTION AHEAD")
                    .font(.caption.bold())
                    .foregroundStyle(status == .blocked ? .red : AppTheme.accent)
                Text("\(hazard.name) — \(navigationService.formatDistance(distance))")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer()

            if hazard.type == .weight_limit, let limit = hazard.weightLimit {
                Text(String(format: "%.0ft", limit))
                    .font(.headline.bold())
                    .foregroundStyle(status.color)
            } else {
                Text(String(format: "%.1fm", hazard.clearanceHeight))
                    .font(.headline.bold())
                    .foregroundStyle(status.color)
            }
        }
        .padding(12)
        .background(
            status == .blocked
                ? AnyShapeStyle(Color.red.opacity(0.12))
                : AnyShapeStyle(AppTheme.accent.opacity(0.12)),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(status == .blocked ? .red.opacity(0.3) : AppTheme.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", speedKmh))
                        .font(.system(size: 28, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("km/h")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                .frame(width: 64, height: 64)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

                VStack(spacing: 4) {
                    Text(navigationService.formatETA(navigationService.estimatedTimeRemaining))
                        .font(.title3.bold())
                    HStack(spacing: 12) {
                        Label(navigationService.formatDistance(navigationService.totalDistanceRemaining), systemImage: "road.lanes")
                        if let arrival = arrivalTime {
                            Label(arrival, systemImage: "clock")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                truckDimensionsBadge
            }

            HStack(spacing: 12) {
                Button {
                    navigationService.stopNavigation()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.red, in: Circle())
                }

                Spacer()

                Button {
                    showStepsList = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.body.bold())
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.thickMaterial, in: Circle())
                }

                Button {
                    isCameraLocked = true
                    isProgrammaticCameraMove = true
                    if let loc = locationService.userLocation {
                        updateCamera(for: loc)
                    }
                } label: {
                    Image(systemName: isCameraLocked ? "location.fill" : "location")
                        .font(.body.bold())
                        .foregroundStyle(isCameraLocked ? .white : .blue)
                        .frame(width: 44, height: 44)
                        .background(isCameraLocked ? AnyShapeStyle(.blue) : AnyShapeStyle(.thickMaterial), in: Circle())
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    private var truckDimensionsBadge: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.and.down")
                    .font(.system(size: 8, weight: .bold))
                Text(String(format: "%.1fm", viewModel.truckProfile.height))
                    .font(.system(size: 10, weight: .heavy).monospacedDigit())
            }
            HStack(spacing: 4) {
                Image(systemName: "scalemass")
                    .font(.system(size: 8, weight: .bold))
                Text(String(format: "%.1ft", viewModel.truckProfile.weight))
                    .font(.system(size: 10, weight: .heavy).monospacedDigit())
            }
        }
        .foregroundStyle(.secondary)
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var arrivalTime: String? {
        let arrival = Date().addingTimeInterval(navigationService.estimatedTimeRemaining)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: arrival)
    }

    private var arrivedOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "flag.checkered.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)

                Text("You've Arrived!")
                    .font(.title.bold())

                Text("You have reached your destination.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    navigationService.stopNavigation()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
            .padding(30)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 30)
        }
    }

    private var stepsListSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(navigationService.routeSteps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(index == navigationService.currentStepIndex ? .blue : Color(.tertiarySystemFill))
                                .frame(width: 36, height: 36)

                            Image(systemName: navigationService.maneuverIcon(for: step))
                                .font(.caption.bold())
                                .foregroundStyle(index == navigationService.currentStepIndex ? .white : .secondary)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.instructions)
                                .font(.subheadline)
                                .fontWeight(index == navigationService.currentStepIndex ? .bold : .regular)

                            if step.distance > 0 {
                                Text(navigationService.formatDistance(step.distance))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if index < navigationService.currentStepIndex {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .listRowBackground(
                        index == navigationService.currentStepIndex
                            ? Color.blue.opacity(0.08)
                            : Color.clear
                    )
                }
            }
            .navigationTitle("Directions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showStepsList = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    private var nearestBlockedHazard: Hazard? {
        guard let location = locationService.userLocation else { return nil }
        var nearest: Hazard?
        var nearestDist: CLLocationDistance = .greatestFiniteMagnitude
        for hazard in navigationService.upcomingHazards {
            let status = viewModel.hazardStatus(hazard)
            guard status == .blocked || status == .tight else { continue }
            let hazardLoc = CLLocation(latitude: hazard.latitude, longitude: hazard.longitude)
            let dist = location.distance(from: hazardLoc)
            if dist < nearestDist {
                nearestDist = dist
                nearest = hazard
            }
        }
        return nearest
    }

    private func updateCamera(for location: CLLocation) {
        let heading = location.course >= 0 ? location.course : 0
        let speed = max(0, location.speed)
        let distance: Double
        if speed < 5 {
            distance = 600
        } else if speed < 20 {
            distance = 800
        } else if speed < 40 {
            distance = 1000
        } else {
            distance = 1400
        }
        let animDuration = speed < 5 ? 1.5 : 1.0
        isProgrammaticCameraMove = true
        withAnimation(.easeInOut(duration: animDuration)) {
            position = .camera(MapCamera(
                centerCoordinate: location.coordinate,
                distance: distance,
                heading: heading,
                pitch: 55
            ))
        }
        Task {
            try? await Task.sleep(for: .seconds(animDuration + 0.2))
            isProgrammaticCameraMove = false
        }
    }
}
