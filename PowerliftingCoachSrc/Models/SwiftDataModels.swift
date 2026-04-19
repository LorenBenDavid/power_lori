import SwiftData
import Foundation

// MARK: - UserProfile

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var supabaseId: String
    var email: String?
    var phone: String?
    var createdAt: Date
    var onboardingComplete: Bool
    var sessionToken: String?

    @Relationship(deleteRule: .cascade) var athleteProfile: AthleteProfile?
    @Relationship(deleteRule: .cascade) var programs: [TrainingProgram]
    @Relationship(deleteRule: .cascade) var chatMessages: [ChatMessage]

    init(supabaseId: String, email: String? = nil, phone: String? = nil) {
        self.id = UUID()
        self.supabaseId = supabaseId
        self.email = email
        self.phone = phone
        self.createdAt = Date()
        self.onboardingComplete = false
        self.programs = []
        self.chatMessages = []
    }
}

// MARK: - AthleteProfile

@Model
final class AthleteProfile {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var firstName: String
    var lastName: String
    var gender: String
    var age: Int
    var weightKg: Double
    var heightCm: Double
    var experienceLevel: String
    var trainingDaysPerWeek: Int
    var goal: String
    var focusLifts: [String]
    var createdAt: Date
    var updatedAt: Date

    // Optional 1RM fields (from PRD Section 15 recommendation)
    var squatMaxKg: Double?
    var benchMaxKg: Double?
    var deadliftMaxKg: Double?

    init(
        userId: UUID,
        firstName: String,
        lastName: String,
        gender: String,
        age: Int,
        weightKg: Double,
        heightCm: Double,
        experienceLevel: String,
        trainingDaysPerWeek: Int,
        goal: String,
        focusLifts: [String]
    ) {
        self.id = UUID()
        self.userId = userId
        self.firstName = firstName
        self.lastName = lastName
        self.gender = gender
        self.age = age
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.experienceLevel = experienceLevel
        self.trainingDaysPerWeek = trainingDaysPerWeek
        self.goal = goal
        self.focusLifts = focusLifts
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - TrainingProgram

@Model
final class TrainingProgram {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var weekNumber: Int
    var blockType: String // accumulation / intensification / peak / deload
    var programJson: Data // Stored as JSON
    var generatedAt: Date
    var isCurrent: Bool
    var supabaseId: String?

    @Relationship(deleteRule: .cascade) var sessions: [TrainingSession]

    init(userId: UUID, weekNumber: Int, blockType: String, programJson: Data) {
        self.id = UUID()
        self.userId = userId
        self.weekNumber = weekNumber
        self.blockType = blockType
        self.programJson = programJson
        self.generatedAt = Date()
        self.isCurrent = true
        self.sessions = []
    }
}

// MARK: - TrainingSession

@Model
final class TrainingSession {
    @Attribute(.unique) var id: UUID
    var programId: UUID
    var userId: UUID
    var dayNumber: Int
    var mainLift: String
    var status: String // locked / available / in_progress / completed
    var startedAt: Date?
    var completedAt: Date?
    var supabaseId: String?
    var pendingSync: Bool

    @Relationship(deleteRule: .cascade) var exercises: [SessionExercise]

    init(programId: UUID, userId: UUID, dayNumber: Int, mainLift: String) {
        self.id = UUID()
        self.programId = programId
        self.userId = userId
        self.dayNumber = dayNumber
        self.mainLift = mainLift
        self.status = "locked"
        self.pendingSync = false
        self.exercises = []
    }
}

// MARK: - SessionExercise

@Model
final class SessionExercise {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var exerciseName: String
    var programmedSets: Int
    var programmedReps: Int
    var programmedWeightKg: Double
    var rpeTarget: Int
    var notes: String?
    var orderIndex: Int

    @Relationship(deleteRule: .cascade) var setLogs: [SetLog]

    init(
        sessionId: UUID,
        exerciseName: String,
        programmedSets: Int,
        programmedReps: Int,
        programmedWeightKg: Double,
        rpeTarget: Int,
        notes: String? = nil,
        orderIndex: Int
    ) {
        self.id = UUID()
        self.sessionId = sessionId
        self.exerciseName = exerciseName
        self.programmedSets = programmedSets
        self.programmedReps = programmedReps
        self.programmedWeightKg = programmedWeightKg
        self.rpeTarget = rpeTarget
        self.notes = notes
        self.orderIndex = orderIndex
        self.setLogs = []
    }
}

// MARK: - SetLog

@Model
final class SetLog {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var setNumber: Int
    var actualWeightKg: Double
    var actualReps: Int
    var rpeActual: Int
    var loggedAt: Date
    var pendingSync: Bool
    var supabaseId: String?

    init(
        exerciseId: UUID,
        setNumber: Int,
        actualWeightKg: Double,
        actualReps: Int,
        rpeActual: Int
    ) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.setNumber = setNumber
        self.actualWeightKg = actualWeightKg
        self.actualReps = actualReps
        self.rpeActual = rpeActual
        self.loggedAt = Date()
        self.pendingSync = true
    }
}

// MARK: - ChatMessage

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var role: String // user / assistant
    var content: String
    var createdAt: Date
    var flaggedInjury: Bool
    var flaggedExerciseSwap: Bool
    var pendingSync: Bool
    var supabaseId: String?

    init(userId: UUID, role: String, content: String) {
        self.id = UUID()
        self.userId = userId
        self.role = role
        self.content = content
        self.createdAt = Date()
        self.flaggedInjury = false
        self.flaggedExerciseSwap = false
        self.pendingSync = true
    }
}

// MARK: - Program JSON Decodable Models

struct ProgramResponse: Codable {
    let weekNumber: Int
    let block: String
    let sessions: [SessionData]
    let coachNotes: String

    enum CodingKeys: String, CodingKey {
        case weekNumber = "week_number"
        case block
        case sessions
        case coachNotes = "coach_notes"
    }
}

struct SessionData: Codable {
    let day: Int
    let mainLift: String
    let exercises: [ExerciseData]

    enum CodingKeys: String, CodingKey {
        case day
        case mainLift = "main_lift"
        case exercises
    }
}

struct ExerciseData: Codable {
    let name: String
    let sets: Int
    let reps: Int
    let weightKg: Double
    let rpeTarget: Int
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case name
        case sets
        case reps
        case weightKg = "weight_kg"
        case rpeTarget = "rpe_target"
        case notes
    }
}
