import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) var modelContext

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
        .task {
            // Give AuthManager access to SwiftData before restoring session
            authManager.configure(modelContext: modelContext)
            if authManager.appState == .loading {
                await authManager.restoreSession()
            }
        }
    }
}
