import Foundation
import UserNotifications

@Observable
final class NotificationService {
    var isAuthorized: Bool = false
    var notificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "notificationsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "notificationsEnabled") }
    }

    private let center = UNUserNotificationCenter.current()

    init() {
        Task { await checkAuthorization() }
    }

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            if granted {
                notificationsEnabled = true
            }
        } catch {
            isAuthorized = false
        }
    }

    func checkAuthorization() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    func scheduleHazardAlert(hazardName: String, status: String, clearance: String) {
        guard isAuthorized, notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Hazard Alert"
        content.body = "\(hazardName) is now \(status) (\(clearance))"
        content.sound = .default
        content.categoryIdentifier = "HAZARD_ALERT"

        let request = UNNotificationRequest(
            identifier: "hazard_\(hazardName.hashValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func scheduleDockStatusNotification(dockName: String, message: String) {
        guard isAuthorized, notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Dock Update"
        content.body = "\(dockName): \(message)"
        content.sound = .default
        content.categoryIdentifier = "DOCK_UPDATE"

        let request = UNNotificationRequest(
            identifier: "dock_\(dockName.hashValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func scheduleProximityAlert(hazardName: String, distance: String) {
        guard isAuthorized, notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Nearby Hazard"
        content.body = "\(hazardName) is \(distance) ahead on your route"
        content.sound = .default
        content.categoryIdentifier = "PROXIMITY_ALERT"
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "proximity_\(hazardName.hashValue)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func scheduleRouteSummaryAlert(blockedCount: Int, tightCount: Int, summary: String) {
        guard isAuthorized, notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Route Hazards Found"
        var body = ""
        if blockedCount > 0 { body += "\(blockedCount) blocked" }
        if tightCount > 0 {
            if !body.isEmpty { body += ", " }
            body += "\(tightCount) tight"
        }
        body += " hazards on your route"
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "ROUTE_SUMMARY"
        if blockedCount > 0 {
            content.interruptionLevel = .timeSensitive
        }

        let request = UNNotificationRequest(
            identifier: "route_summary_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func removeAllPendingNotifications() {
        center.removeAllPendingNotificationRequests()
    }
}
