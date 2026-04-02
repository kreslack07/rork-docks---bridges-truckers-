import Foundation

nonisolated enum TruckType: String, CaseIterable, Sendable, Codable {
    case semi_trailer, b_double, rigid, delivery_van, road_train, custom

    var label: String {
        switch self {
        case .semi_trailer: "Semi-Trailer"
        case .b_double: "B-Double"
        case .rigid: "Rigid Truck"
        case .delivery_van: "Delivery Van"
        case .road_train: "Road Train"
        case .custom: "Custom"
        }
    }

    var defaultHeight: Double {
        switch self {
        case .semi_trailer: 4.3
        case .b_double: 4.3
        case .rigid: 3.5
        case .delivery_van: 3.0
        case .road_train: 4.3
        case .custom: 4.0
        }
    }

    var defaultWeight: Double {
        switch self {
        case .semi_trailer: 42.5
        case .b_double: 62.5
        case .rigid: 22.5
        case .delivery_van: 4.5
        case .road_train: 79.0
        case .custom: 20.0
        }
    }

    var defaultWidth: Double {
        switch self {
        case .delivery_van: 2.1
        default: 2.5
        }
    }

    var icon: String {
        switch self {
        case .semi_trailer: "truck.box.fill"
        case .b_double: "truck.box.fill"
        case .rigid: "truck.box.badge.clock.fill"
        case .delivery_van: "car.rear.fill"
        case .road_train: "truck.box.fill"
        case .custom: "wrench.and.screwdriver.fill"
        }
    }
}

nonisolated struct TruckProfile: Codable, Sendable, Equatable {
    var name: String
    var height: Double
    var weight: Double
    var width: Double
    var type: TruckType
    var plateNumber: String

    static let `default` = TruckProfile(
        name: "",
        height: 4.3,
        weight: 42.5,
        width: 2.5,
        type: .semi_trailer,
        plateNumber: ""
    )
}
