import Foundation
import WidgetKit

nonisolated enum SharedAppGroup {
    static let groupID = "group.app.rork.8pyi6v6f1q9v9awwz3f8l"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: groupID) ?? .standard
    }
}

nonisolated enum SharedKeys {
    static let blockedCount = "widget_blockedCount"
    static let tightCount = "widget_tightCount"
    static let safeCount = "widget_safeCount"
    static let truckTypeName = "widget_truckTypeName"
    static let truckHeight = "widget_truckHeight"
    static let totalHazards = "widget_totalHazards"
    static let lastUpdated = "widget_lastUpdated"
}

nonisolated enum SharedDataService {
    static func updateWidgetData(
        blockedCount: Int,
        tightCount: Int,
        safeCount: Int,
        truckTypeName: String,
        truckHeight: Double,
        totalHazards: Int
    ) {
        let defaults = SharedAppGroup.defaults
        defaults.set(blockedCount, forKey: SharedKeys.blockedCount)
        defaults.set(tightCount, forKey: SharedKeys.tightCount)
        defaults.set(safeCount, forKey: SharedKeys.safeCount)
        defaults.set(truckTypeName, forKey: SharedKeys.truckTypeName)
        defaults.set(truckHeight, forKey: SharedKeys.truckHeight)
        defaults.set(totalHazards, forKey: SharedKeys.totalHazards)
        defaults.set(Date().timeIntervalSince1970, forKey: SharedKeys.lastUpdated)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
