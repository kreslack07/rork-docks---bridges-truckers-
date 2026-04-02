import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "truck.box.fill",
            iconColor: AppTheme.accent,
            title: "Built for Truckers",
            subtitle: "Know your clearances before you hit the road. We map low bridges, wires, and weight limits across Australia."
        ),
        OnboardingPage(
            icon: "exclamationmark.triangle.fill",
            iconColor: .red,
            title: "Stay Safe on Every Route",
            subtitle: "Set your truck's height and weight to instantly see which hazards are blocked, tight, or clear for your vehicle."
        ),
        OnboardingPage(
            icon: "map.fill",
            iconColor: AppTheme.golden,
            title: "Find Docks & Plan Routes",
            subtitle: "Locate loading docks, search destinations, and check hazards along your route — all in one app."
        )
    ]

    var body: some View {
        ZStack {
            AppTheme.onboardingGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageView(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? AppTheme.accent : Color.white.opacity(0.3))
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(.spring(duration: 0.3), value: currentPage)
                        }
                    }

                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(duration: 0.35)) {
                                currentPage += 1
                            }
                        } else {
                            hasCompletedOnboarding = true
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.cardGradient, in: RoundedRectangle(cornerRadius: 16))
                            .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, y: 4)
                    }

                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            hasCompletedOnboarding = true
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.15))
                    .frame(width: 130, height: 130)
                Circle()
                    .fill(page.iconColor.opacity(0.08))
                    .frame(width: 170, height: 170)
                Image(systemName: page.icon)
                    .font(.system(size: 52))
                    .foregroundStyle(page.iconColor)
                    .shadow(color: page.iconColor.opacity(0.4), radius: 12, y: 4)
            }

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}

private nonisolated struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
}
