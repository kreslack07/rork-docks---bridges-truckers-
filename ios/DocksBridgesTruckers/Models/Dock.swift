import Foundation
import CoreLocation

nonisolated enum BusinessCategory: String, CaseIterable, Sendable, Codable {
    case hotel, restaurant, warehouse, hospital, shopping, factory
    case port, supermarket, fuel, construction, office, other

    var label: String {
        switch self {
        case .hotel: "Hotel & Resort"
        case .restaurant: "Restaurant & Dining"
        case .warehouse: "Warehouse & Distribution"
        case .hospital: "Hospital & Medical"
        case .shopping: "Shopping Centre"
        case .factory: "Factory & Manufacturing"
        case .port: "Port & Terminal"
        case .supermarket: "Supermarket & Retail"
        case .fuel: "Fuel & Truck Stop"
        case .construction: "Construction Site"
        case .office: "Office Building"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .hotel: "bed.double.fill"
        case .restaurant: "fork.knife"
        case .warehouse: "shippingbox.fill"
        case .hospital: "cross.fill"
        case .shopping: "bag.fill"
        case .factory: "building.2.fill"
        case .port: "ferry.fill"
        case .supermarket: "cart.fill"
        case .fuel: "fuelpump.fill"
        case .construction: "hammer.fill"
        case .office: "building.fill"
        case .other: "mappin.and.ellipse"
        }
    }
}

nonisolated enum DockType: String, CaseIterable, Sendable, Codable {
    case loading, unloading, both

    var label: String {
        switch self {
        case .loading: "Loading"
        case .unloading: "Unloading"
        case .both: "Loading & Unloading"
        }
    }
}

nonisolated struct Dock: Identifiable, Sendable, Codable, Equatable {
    let id: String
    let name: String
    let business: String
    let businessCategory: BusinessCategory
    let address: String
    let city: String
    let state: String
    let latitude: Double
    let longitude: Double
    let description: String
    let dockType: DockType
    let accessNotes: String
    let isOffRoad: Bool
    let operatingHours: String?
    let phone: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
