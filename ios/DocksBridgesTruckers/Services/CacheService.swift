import Foundation
import Network

nonisolated enum CacheService {
    private static let hazardsKey = "cached_hazards"
    private static let docksKey = "cached_docks"
    private static let hazardsCacheTimestampKey = "cached_hazards_timestamp"
    private static let docksCacheTimestampKey = "cached_docks_timestamp"

    private static var defaults: UserDefaults {
        SharedAppGroup.defaults
    }

    static func saveHazards(_ hazards: [Hazard]) {
        guard let data = try? JSONEncoder().encode(hazards) else { return }
        defaults.set(data, forKey: hazardsKey)
        defaults.set(Date().timeIntervalSince1970, forKey: hazardsCacheTimestampKey)
    }

    static func loadHazards() -> [Hazard]? {
        guard let data = defaults.data(forKey: hazardsKey),
              let hazards = try? JSONDecoder().decode([Hazard].self, from: data) else { return nil }
        return hazards
    }

    static func hazardsCacheDate() -> Date? {
        let ts = defaults.double(forKey: hazardsCacheTimestampKey)
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    static func saveDocks(_ docks: [Dock]) {
        guard let data = try? JSONEncoder().encode(docks) else { return }
        defaults.set(data, forKey: docksKey)
        defaults.set(Date().timeIntervalSince1970, forKey: docksCacheTimestampKey)
    }

    static func loadDocks() -> [Dock]? {
        guard let data = defaults.data(forKey: docksKey),
              let docks = try? JSONDecoder().decode([Dock].self, from: data) else { return nil }
        return docks
    }

    static func docksCacheDate() -> Date? {
        let ts = defaults.double(forKey: docksCacheTimestampKey)
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    static func isCacheStale(cacheDate: Date?, maxAge: TimeInterval = 3600) -> Bool {
        guard let cacheDate else { return true }
        return Date().timeIntervalSince(cacheDate) > maxAge
    }
}

@Observable
final class NetworkMonitor {
    var isConnected: Bool = true
    var connectionType: NWInterface.InterfaceType?

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init() {
        let pathMonitor = NWPathMonitor()
        self.monitor = pathMonitor
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else {
                    self?.connectionType = nil
                }
            }
        }
        pathMonitor.start(queue: queue)
    }

    var connectionDescription: String {
        guard let connectionType else { return "Unknown" }
        if connectionType == .wifi { return "Wi-Fi" }
        if connectionType == .cellular { return "Cellular" }
        return "Other"
    }

    deinit {
        monitor.cancel()
    }
}
