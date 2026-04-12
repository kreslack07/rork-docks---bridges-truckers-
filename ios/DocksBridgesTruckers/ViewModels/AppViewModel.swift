import Foundation
import SwiftUI
import MapKit
import WidgetKit

@Observable
final class AppViewModel {
    var notificationService: NotificationService?
    var truckProfile: TruckProfile {
        didSet {
            guard truckProfile != oldValue else { return }
            invalidateCaches()
            syncWidgetData()
        }
    }
    var docks: [Dock] = [] {
        didSet {
            guard isInitialized else { return }
            rebuildDockIndex()
            CacheService.saveDocks(docks)
        }
    }
    var hazards: [Hazard] = [] {
        didSet {
            guard isInitialized else { return }
            rebuildHazardIndex()
            invalidateCaches()
            syncWidgetData()
            CacheService.saveHazards(hazards)
        }
    }
    private var isInitialized: Bool = false
    var hazardFilter: HazardFilter = .all {
        didSet {
            guard hazardFilter != oldValue else { return }
            _filteredHazardsCache = nil
            _filteredHazardsFilter = nil
        }
    }
    var favouriteDockIDs: Set<String> = []
    var favouriteHazardIDs: Set<String> = []
    var activeRoute: MKRoute?
    var activeRouteHazards: [Hazard] = []
    var lastDataRefresh: Date?

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var statusCache: [String: HazardStatus] = [:]
    private var dockIndex: [String: Dock] = [:]
    private var hazardIndex: [String: Hazard] = [:]
    private(set) var blockedCount: Int = 0
    private(set) var tightCount: Int = 0

    private var _filteredHazardsCache: [Hazard]?
    private var _filteredHazardsFilter: HazardFilter?

    var filteredHazards: [Hazard] {
        if let cached = _filteredHazardsCache, _filteredHazardsFilter == hazardFilter {
            return cached
        }
        let base: [Hazard]
        switch hazardFilter {
        case .all: base = hazards
        case .bridge: base = hazards.filter { $0.type == .bridge }
        case .wire: base = hazards.filter { $0.type == .wire }
        case .weight_limit: base = hazards.filter { $0.type == .weight_limit }
        }
        let result = base.sorted { hazardStatus($0).sortOrder < hazardStatus($1).sortOrder }
        _filteredHazardsCache = result
        _filteredHazardsFilter = hazardFilter
        return result
    }

    var favouriteDocks: [Dock] {
        docks.filter { favouriteDockIDs.contains($0.id) }
    }

    var favouriteHazards: [Hazard] {
        hazards.filter { favouriteHazardIDs.contains($0.id) }
    }

    var lastRefreshFormatted: String? {
        guard let date = lastDataRefresh else { return nil }
        return Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    private func invalidateCaches() {
        statusCache = [:]
        _filteredHazardsCache = nil
        _filteredHazardsFilter = nil
        var blocked = 0
        var tight = 0
        for hazard in hazards {
            let s = hazardStatus(hazard)
            if s == .blocked { blocked += 1 }
            else if s == .tight { tight += 1 }
        }
        blockedCount = blocked
        tightCount = tight
    }

    private func rebuildDockIndex() {
        dockIndex = Dictionary(uniqueKeysWithValues: docks.map { ($0.id, $0) })
    }

    private func rebuildHazardIndex() {
        hazardIndex = Dictionary(uniqueKeysWithValues: hazards.map { ($0.id, $0) })
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "truckProfile"),
           let profile = try? JSONDecoder().decode(TruckProfile.self, from: data) {
            self.truckProfile = profile
        } else {
            self.truckProfile = .default
        }
        if let favData = UserDefaults.standard.data(forKey: "favouriteDockIDs"),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: favData) {
            self.favouriteDockIDs = ids
        }
        if let hazFavData = UserDefaults.standard.data(forKey: "favouriteHazardIDs"),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: hazFavData) {
            self.favouriteHazardIDs = ids
        }
        self.hazards = CacheService.loadHazards() ?? MockData.hazards
        self.docks = CacheService.loadDocks() ?? MockData.docks
        self.lastDataRefresh = CacheService.hazardsCacheDate()
        rebuildDockIndex()
        rebuildHazardIndex()
        invalidateCaches()
        isInitialized = true
    }

    func dock(byID id: String) -> Dock? {
        dockIndex[id]
    }

    func hazard(byID id: String) -> Hazard? {
        hazardIndex[id]
    }

    func clearRoute() {
        activeRoute = nil
        activeRouteHazards = []
    }

    func saveProfile() {
        if let data = try? JSONEncoder().encode(truckProfile) {
            UserDefaults.standard.set(data, forKey: "truckProfile")
        }
    }

    func updateTruckType(_ type: TruckType) {
        truckProfile.type = type
        truckProfile.height = type.defaultHeight
        truckProfile.weight = type.defaultWeight
        truckProfile.width = type.defaultWidth
        truckProfile.length = type.defaultLength
        saveProfile()
    }

    func toggleFavourite(_ dockID: String) {
        if favouriteDockIDs.contains(dockID) {
            favouriteDockIDs.remove(dockID)
        } else {
            favouriteDockIDs.insert(dockID)
        }
        if let data = try? JSONEncoder().encode(favouriteDockIDs) {
            UserDefaults.standard.set(data, forKey: "favouriteDockIDs")
        }
    }

    func isFavourite(_ dockID: String) -> Bool {
        favouriteDockIDs.contains(dockID)
    }

    func toggleHazardFavourite(_ hazardID: String) {
        if favouriteHazardIDs.contains(hazardID) {
            favouriteHazardIDs.remove(hazardID)
        } else {
            favouriteHazardIDs.insert(hazardID)
        }
        if let data = try? JSONEncoder().encode(favouriteHazardIDs) {
            UserDefaults.standard.set(data, forKey: "favouriteHazardIDs")
        }
    }

    func isHazardFavourite(_ hazardID: String) -> Bool {
        favouriteHazardIDs.contains(hazardID)
    }

    func hazardStatus(_ hazard: Hazard) -> HazardStatus {
        if let cached = statusCache[hazard.id] { return cached }
        let status: HazardStatus
        if hazard.type == .weight_limit, let limit = hazard.weightLimit {
            if truckProfile.weight > limit { status = .blocked }
            else if truckProfile.weight > limit * 0.9 { status = .tight }
            else { status = .safe }
        } else {
            let heightStatus: HazardStatus
            if truckProfile.height > hazard.clearanceHeight {
                heightStatus = .blocked
            } else if truckProfile.height > hazard.clearanceHeight - 0.3 {
                heightStatus = .tight
            } else {
                heightStatus = .safe
            }

            let widthStatus: HazardStatus
            if let widthLimit = hazard.widthLimit {
                if truckProfile.width > widthLimit {
                    widthStatus = .blocked
                } else if truckProfile.width > widthLimit - 0.3 {
                    widthStatus = .tight
                } else {
                    widthStatus = .safe
                }
            } else {
                widthStatus = .safe
            }

            if heightStatus == .blocked || widthStatus == .blocked {
                status = .blocked
            } else if heightStatus == .tight || widthStatus == .tight {
                status = .tight
            } else {
                status = .safe
            }
        }
        statusCache[hazard.id] = status
        return status
    }

    func cycleFilter() {
        let allCases = HazardFilter.allCases
        guard let idx = allCases.firstIndex(of: hazardFilter) else { return }
        let next = allCases.index(after: idx)
        hazardFilter = next < allCases.endIndex ? allCases[next] : allCases[0]
    }

    func refreshData() async {
        try? await Task.sleep(for: .milliseconds(300))
        let cachedHazards = CacheService.loadHazards()
        let cachedDocks = CacheService.loadDocks()
        hazards = cachedHazards ?? MockData.hazards
        docks = cachedDocks ?? MockData.docks
        lastDataRefresh = Date()
    }

    func setRoute(_ route: MKRoute, hazards: [Hazard]) {
        activeRoute = route
        activeRouteHazards = hazards
        notifyRouteHazards(hazards)
    }

    private func notifyRouteHazards(_ routeHazards: [Hazard]) {
        guard let ns = notificationService else { return }
        let blocked = routeHazards.filter { hazardStatus($0) == .blocked }
        let tight = routeHazards.filter { hazardStatus($0) == .tight }
        guard !blocked.isEmpty || !tight.isEmpty else { return }
        var summary = ""
        if !blocked.isEmpty {
            let names = blocked.prefix(3).map(\.name).joined(separator: ", ")
            summary += "\(blocked.count) BLOCKED: \(names)"
            if blocked.count > 3 { summary += " +\(blocked.count - 3) more" }
        }
        if !tight.isEmpty {
            if !summary.isEmpty { summary += "\n" }
            let names = tight.prefix(3).map(\.name).joined(separator: ", ")
            summary += "\(tight.count) TIGHT: \(names)"
            if tight.count > 3 { summary += " +\(tight.count - 3) more" }
        }
        ns.scheduleRouteSummaryAlert(
            blockedCount: blocked.count,
            tightCount: tight.count,
            summary: summary
        )
    }

    func syncWidgetData() {
        let blocked = blockedCount
        let tight = tightCount
        let safe = hazards.count - blocked - tight
        SharedDataService.updateWidgetData(
            blockedCount: blocked,
            tightCount: tight,
            safeCount: safe,
            truckTypeName: truckProfile.type.label,
            truckHeight: truckProfile.height,
            totalHazards: hazards.count
        )
    }
}

nonisolated enum HazardStatus: Sendable {
    case safe, tight, blocked

    var label: String {
        switch self {
        case .safe: "CLEAR"
        case .tight: "TIGHT"
        case .blocked: "BLOCKED"
        }
    }

    var sortOrder: Int {
        switch self {
        case .blocked: 0
        case .tight: 1
        case .safe: 2
        }
    }
}
