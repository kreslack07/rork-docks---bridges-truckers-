import SwiftUI

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @State private var locationService = LocationService()
    @State private var notificationService = NotificationService()
    @State private var networkMonitor = NetworkMonitor()
    @State private var navigationService = NavigationService()
    @State private var searchCompleter = SearchCompleterService()
    @State private var nearbyPlaces = NearbyPlacesService()
    @State private var selectedTab: AppTab = .route
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showSplash: Bool = true
    @State private var deepLinkHazard: Hazard?
    @State private var deepLinkDock: Dock?

    var body: some View {
        ZStack {
            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
            } else if hasCompletedOnboarding {
                mainContent
                    .transition(.opacity)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showSplash)
        .animation(.easeInOut(duration: 0.4), value: hasCompletedOnboarding)
    }

    private var mainContent: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                Tab("Route", systemImage: "arrow.triangle.turn.up.right.diamond.fill", value: .route) {
                    RouteTabView()
                }

                Tab("Hazards", systemImage: "exclamationmark.triangle.fill", value: .hazards) {
                    HazardsTabView()
                }

                Tab("Favourites", systemImage: "bookmark.fill", value: .favourites) {
                    FavouritesTabView()
                }

                Tab("Profile", systemImage: "person.fill", value: .profile) {
                    ProfileTabView()
                }
            }
            .tint(AppTheme.accent)
            .environment(viewModel)
            .environment(locationService)
            .environment(notificationService)
            .environment(networkMonitor)
            .environment(navigationService)
            .environment(searchCompleter)
            .environment(nearbyPlaces)
            .onAppear {
                viewModel.notificationService = notificationService
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .sheet(item: $deepLinkHazard) { hazard in
                HazardDetailSheet(hazard: hazard)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
            }
            .sheet(item: $deepLinkDock) { dock in
                DockDetailSheet(dock: dock)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
            }

            if !networkMonitor.isConnected {
                offlineBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption.bold())
                .foregroundStyle(.white)
            Text("You're offline — showing cached data")
                .font(.caption.bold())
                .foregroundStyle(.white)
            Spacer()
            if let refresh = viewModel.lastRefreshFormatted {
                Text(refresh)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.navyGradient)
        .padding(.top, 0)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "docksbridges" else { return }
        let host = url.host()
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "hazards":
            if let hazardID = pathComponents.first,
               let hazard = viewModel.hazard(byID: hazardID) {
                selectedTab = .hazards
                deepLinkHazard = hazard
            } else {
                selectedTab = .hazards
            }
        case "docks":
            if let dockID = pathComponents.first,
               let dock = viewModel.dock(byID: dockID) {
                selectedTab = .route
                deepLinkDock = dock
            } else {
                selectedTab = .route
            }
        case "route":
            selectedTab = .route
        case "profile":
            selectedTab = .profile
        case "favourites":
            selectedTab = .favourites
        case "search":
            selectedTab = .route
        case "map":
            selectedTab = .route
        default:
            break
        }
    }
}

nonisolated enum AppTab: Hashable, Sendable {
    case route, hazards, favourites, profile
}
