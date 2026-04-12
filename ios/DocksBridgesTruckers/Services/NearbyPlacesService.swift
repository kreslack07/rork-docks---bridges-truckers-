import Foundation
import MapKit
import CoreLocation

nonisolated struct NearbyPlace: Identifiable, Sendable {
    let id: String
    let name: String
    let category: NearbyCategory
    let coordinate: CLLocationCoordinate2D
    let address: String?
    let distance: CLLocationDistance?

    init(mapItem: MKMapItem, category: NearbyCategory, userLocation: CLLocation?) {
        let coord = mapItem.placemark.coordinate
        self.id = "\(mapItem.name ?? "")_\(coord.latitude)_\(coord.longitude)"
        self.name = mapItem.name ?? "Unknown"
        self.category = category
        self.coordinate = coord
        self.address = mapItem.placemark.title
        if let userLocation {
            self.distance = userLocation.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        } else {
            self.distance = nil
        }
    }
}

nonisolated enum NearbyCategory: String, CaseIterable, Sendable {
    case fuelStation
    case restStop
    case parking
    case food
    case mechanic

    var label: String {
        switch self {
        case .fuelStation: "Fuel"
        case .restStop: "Rest Stops"
        case .parking: "Parking"
        case .food: "Food"
        case .mechanic: "Mechanic"
        }
    }

    var icon: String {
        switch self {
        case .fuelStation: "fuelpump.fill"
        case .restStop: "bed.double.fill"
        case .parking: "p.circle.fill"
        case .food: "fork.knife"
        case .mechanic: "wrench.and.screwdriver.fill"
        }
    }

    var searchQuery: String {
        switch self {
        case .fuelStation: "petrol station truck fuel"
        case .restStop: "rest area truck stop motel"
        case .parking: "truck parking rest area"
        case .food: "restaurant food truck stop"
        case .mechanic: "truck mechanic auto repair"
        }
    }

    var color: Color {
        switch self {
        case .fuelStation: .green
        case .restStop: .blue
        case .parking: .purple
        case .food: .orange
        case .mechanic: .red
        }
    }
}

import SwiftUI

@Observable
final class NearbyPlacesService {
    var places: [NearbyPlace] = []
    var isLoading: Bool = false
    var selectedCategory: NearbyCategory = .fuelStation
    var errorMessage: String?

    func searchNearby(category: NearbyCategory, region: MKCoordinateRegion, userLocation: CLLocation?) async {
        isLoading = true
        errorMessage = nil
        selectedCategory = category

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category.searchQuery
        request.region = region
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            places = response.mapItems
                .map { NearbyPlace(mapItem: $0, category: category, userLocation: userLocation) }
                .sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
            isLoading = false
        } catch {
            places = []
            errorMessage = "Could not find nearby places."
            isLoading = false
        }
    }

    func clear() {
        places = []
        errorMessage = nil
    }
}
