import SwiftUI

struct SplashView: View {
    @State private var isVisible: Bool = false
    @State private var starOpacity: Double = 0
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            AppTheme.splashGradient
                .ignoresSafeArea()

            Canvas { context, size in
                for i in 0..<30 {
                    let x = Double(i * 37 % Int(size.width))
                    let y = Double(i * 53 % Int(size.height))
                    let radius = Double(i % 3 + 1) * 0.5
                    context.opacity = starOpacity * Double(((i * 7) % 10) + 3) / 13.0
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                        with: .color(.white)
                    )
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.12))
                        .frame(width: 120, height: 120)
                        .blur(radius: 10)
                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .shadow(color: AppTheme.accent.opacity(0.6), radius: 24, y: 6)
                }
                .scaleEffect(isVisible ? 1.0 : 0.5)
                .opacity(isVisible ? 1.0 : 0)

                VStack(spacing: 6) {
                    Text("Docks & Bridges")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("Trucker")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.golden)
                        .shadow(color: AppTheme.golden.opacity(0.3), radius: 8, y: 2)
                }
                .opacity(isVisible ? 1.0 : 0)
                .offset(y: isVisible ? 0 : 10)
            }
        }
        .task {
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
                isVisible = true
            }
            withAnimation(.easeIn(duration: 0.8)) {
                starOpacity = 1
            }
            try? await Task.sleep(for: .seconds(1.4))
            onFinish()
        }
    }
}
