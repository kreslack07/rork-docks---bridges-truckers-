import Foundation
import MapKit

@Observable
final class SearchCompleterService: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []
    var isSearching: Bool = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
    }

    func updateSearchRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }

    func search(_ query: String) {
        guard !query.isEmpty else {
            results = []
            isSearching = false
            completer.queryFragment = ""
            return
        }
        isSearching = true
        completer.queryFragment = query
    }

    func clear() {
        completer.queryFragment = ""
        results = []
        isSearching = false
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.results = completer.results
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
        }
    }

    func resolveCompletion(_ completion: MKLocalSearchCompletion) async -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.first
        } catch {
            return nil
        }
    }
}
