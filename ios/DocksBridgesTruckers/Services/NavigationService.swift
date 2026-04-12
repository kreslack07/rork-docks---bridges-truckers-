import Foundation
import MapKit
import CoreLocation

@Observable
final class NavigationService {
    var isNavigating: Bool = false
    var currentRoute: MKRoute?
    var routeSteps: [MKRoute.Step] = []
    var currentStepIndex: Int = 0
    var distanceToNextStep: CLLocationDistance = 0
    var totalDistanceRemaining: CLLocationDistance = 0
    var estimatedTimeRemaining: TimeInterval = 0
    var hasArrived: Bool = false
    var upcomingHazards: [Hazard] = []
    var nextHazardDistance: CLLocationDistance?
    @ObservationIgnored private var hazardLocationCache: [String: CLLocation] = [:]

    var currentStep: MKRoute.Step? {
        guard currentStepIndex < routeSteps.count else { return nil }
        return routeSteps[currentStepIndex]
    }

    var nextStep: MKRoute.Step? {
        let next = currentStepIndex + 1
        guard next < routeSteps.count else { return nil }
        return routeSteps[next]
    }

    func startNavigation(route: MKRoute, hazards: [Hazard]) {
        currentRoute = route
        routeSteps = route.steps.filter { !$0.instructions.isEmpty }
        currentStepIndex = 0
        totalDistanceRemaining = route.distance
        estimatedTimeRemaining = route.expectedTravelTime
        hasArrived = false
        cachedDestination = nil
        upcomingHazards = hazards
        rebuildHazardLocationCache()
        isNavigating = true

        if let first = routeSteps.first {
            distanceToNextStep = first.distance
        }
    }

    func stopNavigation() {
        isNavigating = false
        currentRoute = nil
        routeSteps = []
        currentStepIndex = 0
        distanceToNextStep = 0
        totalDistanceRemaining = 0
        estimatedTimeRemaining = 0
        hasArrived = false
        upcomingHazards = []
        nextHazardDistance = nil
        hazardLocationCache = [:]
        cachedDestination = nil
    }

    func updateLocation(_ location: CLLocation) {
        guard isNavigating, !routeSteps.isEmpty else { return }

        if currentStepIndex < routeSteps.count {
            let step = routeSteps[currentStepIndex]
            let stepEndPoint = stepEndCoordinate(for: step)
            let stepEndLocation = CLLocation(latitude: stepEndPoint.latitude, longitude: stepEndPoint.longitude)
            let newDistance = location.distance(from: stepEndLocation)

            if newDistance < 50 && currentStepIndex < routeSteps.count - 1 {
                currentStepIndex += 1
                if currentStepIndex < routeSteps.count {
                    let nextEnd = stepEndCoordinate(for: routeSteps[currentStepIndex])
                    let nextEndLoc = CLLocation(latitude: nextEnd.latitude, longitude: nextEnd.longitude)
                    distanceToNextStep = location.distance(from: nextEndLoc)
                }
            } else {
                distanceToNextStep = newDistance
            }
        }

        if let dest = destinationCoordinate {
            let destLocation: CLLocation
            if let cached = cachedDestination {
                destLocation = cached
            } else {
                destLocation = CLLocation(latitude: dest.latitude, longitude: dest.longitude)
                cachedDestination = destLocation
            }
            totalDistanceRemaining = location.distance(from: destLocation)

            let speed = location.speed > 1 ? location.speed : 10
            estimatedTimeRemaining = totalDistanceRemaining / speed

            if totalDistanceRemaining < 50 {
                hasArrived = true
            }
        }

        updateHazardDistances(from: location)
    }

    private func updateHazardDistances(from location: CLLocation) {
        guard !upcomingHazards.isEmpty else {
            nextHazardDistance = nil
            return
        }

        var closestDistance: CLLocationDistance = .greatestFiniteMagnitude
        for hazard in upcomingHazards {
            let hazardLocation = hazardLocationCache[hazard.id] ?? CLLocation(latitude: hazard.latitude, longitude: hazard.longitude)
            let dist = location.distance(from: hazardLocation)
            if dist < closestDistance {
                closestDistance = dist
            }
        }
        nextHazardDistance = closestDistance < 50_000 ? closestDistance : nil
    }

    private func rebuildHazardLocationCache() {
        hazardLocationCache = Dictionary(uniqueKeysWithValues: upcomingHazards.map {
            ($0.id, CLLocation(latitude: $0.latitude, longitude: $0.longitude))
        })
    }

    @ObservationIgnored private var cachedDestination: CLLocation?

    private var destinationCoordinate: CLLocationCoordinate2D? {
        guard let route = currentRoute else { return nil }
        let polyline = route.polyline
        let pointCount = polyline.pointCount
        guard pointCount > 0 else { return nil }
        return polyline.points()[pointCount - 1].coordinate
    }

    private func stepEndCoordinate(for step: MKRoute.Step) -> CLLocationCoordinate2D {
        let polyline = step.polyline
        let count = polyline.pointCount
        guard count > 0 else { return CLLocationCoordinate2D() }
        return polyline.points()[count - 1].coordinate
    }

    func maneuverIcon(for step: MKRoute.Step) -> String {
        let instructions = step.instructions.lowercased()
        if instructions.contains("turn left") || instructions.contains("slight left") {
            return "arrow.turn.up.left"
        } else if instructions.contains("turn right") || instructions.contains("slight right") {
            return "arrow.turn.up.right"
        } else if instructions.contains("u-turn") {
            return "arrow.uturn.down"
        } else if instructions.contains("merge") {
            return "arrow.merge"
        } else if instructions.contains("exit") || instructions.contains("off-ramp") {
            return "arrow.triangle.turn.up.right.diamond"
        } else if instructions.contains("roundabout") || instructions.contains("rotary") {
            return "arrow.triangle.capsulepath"
        } else if instructions.contains("arrive") || instructions.contains("destination") {
            return "flag.checkered"
        } else if instructions.contains("keep left") {
            return "arrow.up.left"
        } else if instructions.contains("keep right") {
            return "arrow.up.right"
        } else {
            return "arrow.up"
        }
    }

    func formatDistance(_ meters: CLLocationDistance) -> String {
        Formatters.distance(meters)
    }

    func formatETA(_ seconds: TimeInterval) -> String {
        Formatters.duration(seconds)
    }
}
