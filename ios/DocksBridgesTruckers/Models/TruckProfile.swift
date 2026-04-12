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

    var defaultLength: Double {
        switch self {
        case .semi_trailer: 19.0
        case .b_double: 25.0
        case .rigid: 12.5
        case .delivery_van: 6.5
        case .road_train: 36.5
        case .custom: 12.0
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
    var length: Double
    var type: TruckType
    var plateNumber: String

    static let `default` = TruckProfile(
        name: "",
        height: 4.3,
        weight: 42.5,
        width: 2.5,
        length: 19.0,
        type: .semi_trailer,
        plateNumber: ""
    )

    init(name: String, height: Double, weight: Double, width: Double, length: Double = 19.0, type: TruckType, plateNumber: String) {
        self.name = name
        self.height = height
        self.weight = weight
        self.width = width
        self.length = length
        self.type = type
        self.plateNumber = plateNumber
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        height = try container.decode(Double.self, forKey: .height)
        weight = try container.decode(Double.self, forKey: .weight)
        width = try container.decode(Double.self, forKey: .width)
        length = try container.decodeIfPresent(Double.self, forKey: .length) ?? 19.0
        type = try container.decode(TruckType.self, forKey: .type)
        plateNumber = try container.decode(String.self, forKey: .plateNumber)
    }

    private nonisolated enum CodingKeys: String, CodingKey {
        case name, height, weight, width, length, type, plateNumber
    }
}
