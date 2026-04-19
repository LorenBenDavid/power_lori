import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            switch authManager.appState {
            case .loading:
                SplashView()
            case .unauthenticated:
                AuthView()
            case .onboarding:
                OnboardingView()
            case .authenticated:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: authManager.appState)
    }
}
