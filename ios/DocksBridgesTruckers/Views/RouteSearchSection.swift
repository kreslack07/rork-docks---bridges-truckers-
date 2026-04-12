import SwiftUI
import MapKit

struct RouteSearchBarView: View {
    @Binding var destination: String
    @Binding var isTyping: Bool
    @Binding var showVehicleEditor: Bool
    let isSearching: Bool
    let isCompleterSearching: Bool
    let truckProfile: TruckProfile
    let onSubmit: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.body)

                TextField("Where to?", text: $destination, onEditingChanged: { editing in
                    isTyping = editing
                })
                .font(.body)
                .textContentType(.fullStreetAddress)
                .onSubmit { onSubmit() }

                if isSearching || isCompleterSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                if !destination.isEmpty {
                    Button { onClear() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

            Button { showVehicleEditor = true } label: {
                HStack(spacing: 0) {
                    dimensionPill(icon: "arrow.up.and.down", value: String(format: "%.1fm", truckProfile.height))
                    Divider().frame(height: 20)
                    dimensionPill(icon: "scalemass", value: String(format: "%.1ft", truckProfile.weight))
                    Divider().frame(height: 20)
                    dimensionPill(icon: "arrow.left.and.right", value: String(format: "%.1fm", truckProfile.length))
                }
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func dimensionPill(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.accent)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RouteAutocompleteListView: View {
    let completions: [MKLocalSearchCompletion]
    let onSelect: (MKLocalSearchCompletion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(completions.prefix(8), id: \.self) { completion in
                Button { onSelect(completion) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: completionIcon(for: completion))
                            .foregroundStyle(AppTheme.accent)
                            .font(.body)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            highlightedText(completion.title, ranges: completion.titleHighlightRanges)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if !completion.subtitle.isEmpty {
                                highlightedText(completion.subtitle, ranges: completion.subtitleHighlightRanges)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Image(systemName: "arrow.up.left")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private func highlightedText(_ text: String, ranges: [NSValue]) -> Text {
        guard !ranges.isEmpty else { return Text(text) }
        var result = Text("")
        let nsString = text as NSString
        var lastEnd = 0
        let sortedRanges = ranges.compactMap { $0.rangeValue }.sorted { $0.location < $1.location }
        for range in sortedRanges {
            if range.location > lastEnd {
                let prefix = nsString.substring(with: NSRange(location: lastEnd, length: range.location - lastEnd))
                result = result + Text(prefix)
            }
            let highlighted = nsString.substring(with: range)
            result = result + Text(highlighted).bold()
            lastEnd = range.location + range.length
        }
        if lastEnd < nsString.length {
            let suffix = nsString.substring(from: lastEnd)
            result = result + Text(suffix)
        }
        return result
    }

    private func completionIcon(for completion: MKLocalSearchCompletion) -> String {
        let title = completion.title.lowercased()
        if title.contains("fuel") || title.contains("petrol") || title.contains("gas") { return "fuelpump.fill" }
        if title.contains("hotel") || title.contains("motel") { return "bed.double.fill" }
        if title.contains("hospital") { return "cross.fill" }
        if title.contains("port") || title.contains("terminal") { return "ferry.fill" }
        if title.contains("warehouse") { return "shippingbox.fill" }
        if title.contains("park") { return "p.circle.fill" }
        if title.contains("rest") { return "cup.and.saucer.fill" }
        return "mappin.circle.fill"
    }
}

struct RouteInfoCardView: View {
    let route: MKRoute
    let hazardCount: Int
    let onStartNavigation: () -> Void
    let routeSummaryText: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundStyle(.blue)
                    Text(formatDuration(route.expectedTravelTime))
                        .font(.headline.bold())
                    Text("Time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 40)

                VStack(spacing: 4) {
                    Image(systemName: "road.lanes")
                        .foregroundStyle(.blue)
                    Text(formatDistance(route.distance))
                        .font(.headline.bold())
                    Text("Distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 40)

                VStack(spacing: 4) {
                    Image(systemName: hazardCount == 0 ? "checkmark.shield" : "exclamationmark.triangle")
                        .foregroundStyle(hazardCount == 0 ? .green : .orange)
                    Text("\(hazardCount)")
                        .font(.headline.bold())
                    Text("Hazards")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            Button { onStartNavigation() } label: {
                Label("Start Navigation", systemImage: "location.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 12))
            }

            ShareLink(
                item: routeSummaryText,
                subject: Text("Route Info"),
                message: Text("Route details from Docks & Bridges")
            ) {
                Label("Share Route", systemImage: "square.and.arrow.up")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.accent)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func formatDistance(_ meters: Double) -> String {
        let km = meters / 1000
        if km >= 100 { return String(format: "%.0f km", km) }
        return String(format: "%.1f km", km)
    }
}

struct RouteHazardListView: View {
    let hazards: [Hazard]
    let statusProvider: (Hazard) -> HazardStatus
    let onSelect: (Hazard) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.accent)
                Text("Hazards Near Route")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(hazards.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }

            ForEach(hazards) { hazard in
                let status = statusProvider(hazard)
                Button { onSelect(hazard) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: hazard.type.icon)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(status.color, in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(hazard.name)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Text(hazard.road)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if hazard.type == .weight_limit, let limit = hazard.weightLimit {
                            Text(String(format: "%.0ft", limit))
                                .font(.subheadline.bold())
                                .foregroundStyle(status.color)
                        } else {
                            Text(String(format: "%.1fm", hazard.clearanceHeight))
                                .font(.subheadline.bold())
                                .foregroundStyle(status.color)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                }
                .tint(.primary)
            }
        }
    }
}
