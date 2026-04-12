import Foundation

nonisolated enum APIEndpoint {
    static var baseURL: String {
        let url = Config.EXPO_PUBLIC_RORK_API_BASE_URL
        return url.isEmpty ? "https://api.docksbridgestruckers.com.au/v1" : url
    }

    static var hazardsURL: String { "\(baseURL)/hazards" }
    static var docksURL: String { "\(baseURL)/docks" }
    static var dataVersionURL: String { "\(baseURL)/data/version" }
}

nonisolated struct APIHazardsResponse: Codable, Sendable {
    let hazards: [Hazard]
    let version: String?
    let updatedAt: String?
}

nonisolated struct APIDocksResponse: Codable, Sendable {
    let docks: [Dock]
    let version: String?
    let updatedAt: String?
}

nonisolated struct DataVersionResponse: Codable, Sendable {
    let hazardsVersion: String
    let docksVersion: String
    let updatedAt: String
}

nonisolated enum APIError: Error, Sendable {
    case invalidURL
    case networkError(Error)
    case invalidResponse(Int)
    case decodingError(Error)
    case noData
}

nonisolated enum APIService: Sendable {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    static func fetchHazards() async -> Result<[Hazard], APIError> {
        await fetchAndDecode(from: APIEndpoint.hazardsURL) { (response: APIHazardsResponse) in
            response.hazards
        }
    }

    static func fetchDocks() async -> Result<[Dock], APIError> {
        await fetchAndDecode(from: APIEndpoint.docksURL) { (response: APIDocksResponse) in
            response.docks
        }
    }

    static func checkDataVersion() async -> Result<DataVersionResponse, APIError> {
        await fetchAndDecode(from: APIEndpoint.dataVersionURL) { (response: DataVersionResponse) in
            response
        }
    }

    private static func fetchAndDecode<Raw: Decodable & Sendable, T: Sendable>(
        from urlString: String,
        transform: (Raw) -> T
    ) async -> Result<T, APIError> {
        guard let url = URL(string: urlString) else {
            return .failure(.invalidURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DocksBridgesTrucker/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse(0))
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                return .failure(.invalidResponse(httpResponse.statusCode))
            }
            do {
                let decoded = try JSONDecoder().decode(Raw.self, from: data)
                return .success(transform(decoded))
            } catch {
                return .failure(.decodingError(error))
            }
        } catch {
            return .failure(.networkError(error))
        }
    }
}

nonisolated enum DataRefreshService: Sendable {

    struct RefreshResult: Sendable {
        let hazards: [Hazard]
        let docks: [Dock]
        let source: DataSource
    }

    enum DataSource: Sendable {
        case api
        case cache
        case bundled
    }

    static func refreshData(
        currentHazards: [Hazard],
        currentDocks: [Dock]
    ) async -> RefreshResult {
        async let hazardsResult = APIService.fetchHazards()
        async let docksResult = APIService.fetchDocks()

        let (hResult, dResult) = await (hazardsResult, docksResult)

        let apiHazards: [Hazard]? = switch hResult {
        case .success(let h) where !h.isEmpty: h
        default: nil
        }

        let apiDocks: [Dock]? = switch dResult {
        case .success(let d) where !d.isEmpty: d
        default: nil
        }

        if let apiHazards, let apiDocks {
            return RefreshResult(hazards: apiHazards, docks: apiDocks, source: .api)
        }

        let cachedHazards = CacheService.loadHazards()
        let cachedDocks = CacheService.loadDocks()

        if let cachedHazards, !cachedHazards.isEmpty, let cachedDocks, !cachedDocks.isEmpty {
            let mergedHazards = mergeData(cached: cachedHazards, bundled: MockData.hazards)
            let mergedDocks = mergeData(cached: cachedDocks, bundled: MockData.docks)
            return RefreshResult(hazards: mergedHazards, docks: mergedDocks, source: .cache)
        }

        return RefreshResult(hazards: MockData.hazards, docks: MockData.docks, source: .bundled)
    }

    private static func mergeData<T: Identifiable>(cached: [T], bundled: [T]) -> [T] where T.ID == String {
        let cachedIDs = Set(cached.map(\.id))
        let newFromBundle = bundled.filter { !cachedIDs.contains($0.id) }
        return cached + newFromBundle
    }
}
