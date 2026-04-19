import SwiftUI
import SwiftData
import Combine

enum SlideDirection { case forward, backward }

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep = 0
    @Published var direction: SlideDirection = .forward
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Step data
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var gender = ""
    @Published var age = ""
    @Published var weightKg = ""
    @Published var heightCm = ""
    @Published var experienceLevel = ""
    @Published var trainingDaysPerWeek = ""
    @Published var goal = ""
    @Published var focusLifts: Set<String> = []

    // Optional 1RM (from PRD critique Section 15)
    @Published var squatMaxKg = ""
    @Published var benchMaxKg = ""
    @Published var deadliftMaxKg = ""

    let totalSteps = 11 // 10 questions + 1 summary

    var isLastStep: Bool { currentStep == totalSteps - 1 }

    var isCurrentStepValid: Bool {
        switch currentStep {
        case 0: return !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return !lastName.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return !gender.isEmpty
        case 3:
            guard let a = Int(age) else { return false }
            return a >= 13 && a <= 80
        case 4:
            guard let w = Double(weightKg) else { return false }
            return w >= 30 && w <= 300
        case 5:
            guard let h = Double(heightCm) else { return false }
            return h >= 100 && h <= 250
        case 6: return !experienceLevel.isEmpty
        case 7: return !trainingDaysPerWeek.isEmpty
        case 8: return !goal.isEmpty
        case 9: return !focusLifts.isEmpty
        case 10: return true // Summary
        default: return false
        }
    }

    func goNext() {
        guard isCurrentStepValid, currentStep < totalSteps - 1 else { return }
        direction = .forward
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep += 1
        }
    }

    func goBack() {
        guard currentStep > 0 else { return }
        direction = .backward
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep -= 1
        }
    }

    func submit(authManager: AuthManager, modelContext: ModelContext) async {
        guard let userId = authManager.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        let profile = AthleteProfile(
            userId: userId,
            firstName: firstName,
            lastName: lastName,
            gender: gender,
            age: Int(age) ?? 0,
            weightKg: Double(weightKg) ?? 0,
            heightCm: Double(heightCm) ?? 0,
            experienceLevel: experienceLevel,
            trainingDaysPerWeek: Int(trainingDaysPerWeek) ?? 3,
            goal: goal,
            focusLifts: Array(focusLifts)
        )

        if !squatMaxKg.isEmpty { profile.squatMaxKg = Double(squatMaxKg) }
        if !benchMaxKg.isEmpty { profile.benchMaxKg = Double(benchMaxKg) }
        if !deadliftMaxKg.isEmpty { profile.deadliftMaxKg = Double(deadliftMaxKg) }

        modelContext.insert(profile)
        authManager.currentUser?.athleteProfile = profile

        // Sync profile to Supabase
        if let token = authManager.currentUser?.sessionToken,
           let supabaseUserId = authManager.currentUser?.supabaseId {
            try? await SupabaseService.shared.upsertAthleteProfile(profile, supabaseUserId: supabaseUserId, token: token)
        }

        // Generate initial program
        do {
            let programResponse = try await AIService.shared.generateInitialProgram(profile: profile)
            let programData = try JSONEncoder().encode(programResponse)

            let program = TrainingProgram(
                userId: userId,
                weekNumber: 1,
                blockType: programResponse.block,
                programJson: programData
            )

            // Build sessions from program
            for sessionData in programResponse.sessions {
                let session = TrainingSession(
                    programId: program.id,
                    userId: userId,
                    dayNumber: sessionData.day,
                    mainLift: sessionData.mainLift
                )
                // First session is available, rest are locked
                session.status = sessionData.day == 1 ? "available" : "locked"

                for (index, exerciseData) in sessionData.exercises.enumerated() {
                    let exercise = SessionExercise(
                        sessionId: session.id,
                        exerciseName: exerciseData.name,
                        programmedSets: exerciseData.sets,
                        programmedReps: exerciseData.reps,
                        programmedWeightKg: exerciseData.weightKg,
                        rpeTarget: exerciseData.rpeTarget,
                        notes: exerciseData.notes,
                        orderIndex: index
                    )
                    session.exercises.append(exercise)
                    modelContext.insert(exercise)
                }

                program.sessions.append(session)
                modelContext.insert(session)
            }

            modelContext.insert(program)
            authManager.currentUser?.programs.append(program)

            try modelContext.save()
            authManager.completeOnboarding()
        } catch {
            errorMessage = "Failed to generate your program. Please try again.\n\n\(error.localizedDescription)"
        }
    }
}
