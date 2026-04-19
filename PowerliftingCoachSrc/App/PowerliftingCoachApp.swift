import SwiftUI
import SwiftData

@main
struct PowerliftingCoachApp: App {
    @StateObject private var authManager = AuthManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            AthleteProfile.self,
            TrainingProgram.self,
            TrainingSession.self,
            SessionExercise.self,
            SetLog.self,
            ChatMessage.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .modelContainer(sharedModelContainer)
                .preferredColorScheme(.dark)
        }
    }
}
