import WidgetKit
import SwiftUI

nonisolated enum WidgetSharedKeys {
    static let groupID = "group.app.rork.8pyi6v6f1q9v9awwz3f8l"
    static let blockedCount = "widget_blockedCount"
    static let tightCount = "widget_tightCount"
    static let safeCount = "widget_safeCount"
    static let truckTypeName = "widget_truckTypeName"
    static let truckHeight = "widget_truckHeight"
    static let totalHazards = "widget_totalHazards"
}

nonisolated struct HazardEntry: TimelineEntry {
    let date: Date
    let blockedCount: Int
    let tightCount: Int
    let safeCount: Int
    let truckTypeName: String
    let truckHeight: Double
    let totalHazards: Int
    let lastUpdated: Date?
}

nonisolated struct HazardProvider: TimelineProvider {
    func placeholder(in context: Context) -> HazardEntry {
        HazardEntry(date: .now, blockedCount: 3, tightCount: 5, safeCount: 42, truckTypeName: "Semi-Trailer", truckHeight: 4.3, totalHazards: 50, lastUpdated: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (HazardEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HazardEntry>) -> Void) {
        let entry = readEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readEntry() -> HazardEntry {
        let defaults = UserDefaults(suiteName: WidgetSharedKeys.groupID)
        let lastUpdatedInterval = defaults?.double(forKey: "widget_lastUpdated") ?? 0
        let lastUpdated: Date? = lastUpdatedInterval > 0 ? Date(timeIntervalSince1970: lastUpdatedInterval) : nil
        return HazardEntry(
            date: .now,
            blockedCount: defaults?.integer(forKey: WidgetSharedKeys.blockedCount) ?? 0,
            tightCount: defaults?.integer(forKey: WidgetSharedKeys.tightCount) ?? 0,
            safeCount: defaults?.integer(forKey: WidgetSharedKeys.safeCount) ?? 0,
            truckTypeName: defaults?.string(forKey: WidgetSharedKeys.truckTypeName) ?? "—",
            truckHeight: defaults?.double(forKey: WidgetSharedKeys.truckHeight) ?? 0,
            totalHazards: defaults?.integer(forKey: WidgetSharedKeys.totalHazards) ?? 0,
            lastUpdated: lastUpdated
        )
    }
}

struct SmallWidgetView: View {
    let entry: HazardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(red: 0.95, green: 0.52, blue: 0.07))
                Text("Hazards")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if entry.blockedCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text("\(entry.blockedCount) blocked")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                }
            }

            if entry.tightCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(red: 0.95, green: 0.52, blue: 0.07))
                        .font(.caption)
                    Text("\(entry.tightCount) tight")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(red: 0.95, green: 0.52, blue: 0.07))
                }
            }

            if entry.blockedCount == 0 && entry.tightCount == 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text("All clear")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }
            }

            Text(String(format: "%.1fm · %@", entry.truckHeight, entry.truckTypeName))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .widgetURL(URL(string: "docksbridges://hazards"))
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MediumWidgetView: View {
    let entry: HazardEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "truck.box.fill")
                        .foregroundStyle(Color(red: 0.95, green: 0.52, blue: 0.07))
                    Text("Docks & Bridges")
                        .font(.caption.bold())
                }

                Spacer()

                Text(String(format: "%.1fm", entry.truckHeight))
                    .font(.title2.bold())
                Text(entry.truckTypeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    StatBubble(count: entry.blockedCount, label: "Blocked", color: .red, icon: "xmark.octagon.fill")
                    StatBubble(count: entry.tightCount, label: "Tight", color: Color(red: 0.95, green: 0.52, blue: 0.07), icon: "exclamationmark.triangle.fill")
                    StatBubble(count: entry.safeCount, label: "Clear", color: .green, icon: "checkmark.circle.fill")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .widgetURL(URL(string: "docksbridges://hazards"))
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct StatBubble: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct AccessoryCircularView: View {
    let entry: HazardEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: entry.blockedCount > 0 ? "xmark.octagon.fill" : "checkmark.shield.fill")
                    .font(.caption)
                Text("\(entry.blockedCount)")
                    .font(.title3.bold())
            }
        }
    }
}

struct AccessoryRectangularView: View {
    let entry: HazardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "truck.box.fill")
                    .font(.caption2)
                Text("HAZARD ALERT")
                    .font(.caption2.bold())
            }
            if entry.blockedCount > 0 {
                Text("\(entry.blockedCount) blocked · \(entry.tightCount) tight")
                    .font(.headline)
            } else if entry.tightCount > 0 {
                Text("\(entry.tightCount) tight clearances")
                    .font(.headline)
            } else {
                Text("All routes clear")
                    .font(.headline)
            }
            Text(String(format: "%.1fm %@", entry.truckHeight, entry.truckTypeName))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct AccessoryInlineView: View {
    let entry: HazardEntry

    var body: some View {
        if entry.blockedCount > 0 {
            Label("\(entry.blockedCount) blocked · \(entry.tightCount) tight", systemImage: "exclamationmark.triangle.fill")
        } else if entry.tightCount > 0 {
            Label("\(entry.tightCount) tight clearances", systemImage: "exclamationmark.triangle")
        } else {
            Label("All routes clear", systemImage: "checkmark.shield")
        }
    }
}

struct HazardWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: HazardEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

struct HazardWidget: Widget {
    let kind = "HazardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HazardProvider()) { entry in
            HazardWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Hazard Alert")
        .description("Shows blocked and tight clearance counts for your truck.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
