import Foundation

enum Formatters {
    static func distance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        }
        let km = meters / 1000
        if km >= 100 { return String(format: "%.0f km", km) }
        return String(format: "%.1f km", km)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes < 1 { return "<1 min" }
        return "\(minutes) min"
    }
}
