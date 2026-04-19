import Foundation

final class AIService {
    static let shared = AIService()
    private init() {}

    private var backendURL: String {
        Bundle.main.infoDictionary?["BACKEND_URL"] as? String ?? "http://localhost:3000"
    }

    private var sessionToken: String? {
        guard let data = KeychainManager.load(key: "session_token") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Generate Initial Program

    func generateInitialProgram(profile: AthleteProfile) async throws -> ProgramResponse {
        let body: [String: Any] = [
            "profile": [
                "first_name": profile.firstName,
                "last_name": profile.lastName,
                "gender": profile.gender,
                "age": profile.age,
                "weight_kg": profile.weightKg,
                "height_cm": profile.heightCm,
                "experience_level": profile.experienceLevel,
                "training_days_per_week": profile.trainingDaysPerWeek,
                "goal": profile.goal,
                "focus_lifts": profile.focusLifts,
                "squat_max_kg": profile.squatMaxKg as Any,
                "bench_max_kg": profile.benchMaxKg as Any,
                "deadlift_max_kg": profile.deadliftMaxKg as Any
            ]
        ]
        return try await post(endpoint: "/api/program/generate", body: body)
    }

    // MARK: - Generate Next Week

    func generateNextWeek(
        profile: AthleteProfile,
        history: [WeekHistoryData]
    ) async throws -> ProgramResponse {
        let body: [String: Any] = [
            "profile": [
                "first_name": profile.firstName,
                "last_name": profile.lastName,
                "gender": profile.gender,
                "age": profile.age,
                "weight_kg": profile.weightKg,
                "height_cm": profile.heightCm,
                "experience_level": profile.experienceLevel,
                "training_days_per_week": profile.trainingDaysPerWeek,
                "goal": profile.goal,
                "focus_lifts": profile.focusLifts
            ],
            "history": history.map { week in
                [
                    "week_number": week.weekNumber,
                    "block": week.block,
                    "sessions": week.sessions.map { session in
                        [
                            "day": session.day,
                            "main_lift": session.mainLift,
                            "exercises": session.exercises.map { ex in
                                [
                                    "name": ex.name,
                                    "programmed_sets": ex.programmedSets,
                                    "programmed_reps": ex.programmedReps,
                                    "programmed_weight_kg": ex.programmedWeightKg,
                                    "rpe_target": ex.rpeTarget,
                                    "actual_sets": ex.setLogs.map { log in
                                        [
                                            "set_number": log.setNumber,
                                            "actual_weight_kg": log.actualWeightKg,
                                            "actual_reps": log.actualReps,
                                            "rpe_actual": log.rpeActual
                                        ] as [String: Any]
                                    }
                                ] as [String: Any]
                            }
                        ] as [String: Any]
                    }
                ] as [String: Any]
            }
        ]
        return try await post(endpoint: "/api/program/next-week", body: body)
    }

    // MARK: - Chat

    func sendChatMessage(
        message: String,
        history: [ChatHistoryItem],
        profile: AthleteProfile,
        currentProgram: ProgramResponse?
    ) async throws -> String {
        var body: [String: Any] = [
            "message": message,
            "history": history.map { ["role": $0.role, "content": $0.content] },
            "profile": [
                "first_name": profile.firstName,
                "experience_level": profile.experienceLevel,
                "goal": profile.goal,
                "focus_lifts": profile.focusLifts
            ]
        ]

        if let program = currentProgram,
           let programData = try? JSONEncoder().encode(program),
           let programDict = try? JSONSerialization.jsonObject(with: programData) {
            body["current_program"] = programDict
        }

        let response: ChatResponse = try await post(endpoint: "/api/chat", body: body)
        return response.reply
    }

    // MARK: - HTTP

    private func post<T: Decodable>(endpoint: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: backendURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = sessionToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError(0)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.serverError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Supporting Types for AI

struct ChatResponse: Codable {
    let reply: String
}

struct ChatHistoryItem {
    let role: String
    let content: String
}

struct WeekHistoryData {
    let weekNumber: Int
    let block: String
    let sessions: [SessionHistoryData]
}

struct SessionHistoryData {
    let day: Int
    let mainLift: String
    let exercises: [ExerciseHistoryData]
}

struct ExerciseHistoryData {
    let name: String
    let programmedSets: Int
    let programmedReps: Int
    let programmedWeightKg: Double
    let rpeTarget: Int
    let setLogs: [SetLogHistoryData]
}

struct SetLogHistoryData {
    let setNumber: Int
    let actualWeightKg: Double
    let actualReps: Int
    let rpeActual: Int
}
