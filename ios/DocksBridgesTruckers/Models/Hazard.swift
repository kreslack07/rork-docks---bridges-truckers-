import Foundation
import CoreLocation

nonisolated enum HazardType: String, CaseIterable, Sendable, Codable {
    case bridge, wire, weight_limit

    var label: String {
        switch self {
        case .bridge: "Bridge"
        case .wire: "Wire"
        case .weight_limit: "Weight Limit"
        }
    }

    var icon: String {
        switch self {
        case .bridge: "road.lanes"
        case .wire: "bolt.fill"
        case .weight_limit: "scalemass.fill"
        }
    }
}

nonisolated enum HazardFilter: String, CaseIterable, Sendable {
    case all, bridge, wire, weight_limit

    var label: String {
        switch self {
        case .all: "All"
        case .bridge: "Bridges"
        case .wire: "Wires"
        case .weight_limit: "Weight Limits"
        }
    }
}

nonisolated struct Hazard: Identifiable, Sendable, Codable, Equatable {
    let id: String
    let type: HazardType
    let name: String
    let clearanceHeight: Double
    let road: String
    let city: String
    let state: String
    let latitude: Double
    let longitude: Double
    let description: String
    let lastVerified: String
    let weightLimit: Double?
    let widthLimit: Double?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
