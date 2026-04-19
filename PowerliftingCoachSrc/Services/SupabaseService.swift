import Foundation

final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}

    private var supabaseURL: String {
        Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
    }

    private var supabaseAnonKey: String {
        Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    }

    private var sessionToken: String? {
        guard let data = KeychainManager.load(key: "session_token") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Auth

    func signInWithApple(identityToken: String, fullName: PersonNameComponents?) async throws -> AuthResponse {
        let body: [String: Any] = [
            "provider": "apple",
            "identity_token": identityToken,
            "full_name": [
                "given_name": fullName?.givenName ?? "",
                "family_name": fullName?.familyName ?? ""
            ]
        ]
        return try await post(endpoint: "/auth/v1/token?grant_type=id_token", body: body, requiresAuth: false)
    }

    func signUpWithEmail(email: String, password: String) async throws -> AuthResponse {
        let body: [String: Any] = ["email": email, "password": password]
        return try await post(endpoint: "/auth/v1/signup", body: body, requiresAuth: false)
    }

    func signInWithEmail(email: String, password: String) async throws -> AuthResponse {
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "grant_type": "password"
        ]
        return try await post(endpoint: "/auth/v1/token", body: body, requiresAuth: false)
    }

    func sendOTP(phone: String) async throws {
        let body: [String: Any] = ["phone": phone]
        let _: EmptyResponse = try await post(endpoint: "/auth/v1/otp", body: body, requiresAuth: false)
    }

    func verifyOTP(phone: String, token: String) async throws -> AuthResponse {
        let body: [String: Any] = [
            "phone": phone,
            "token": token,
            "type": "sms"
        ]
        return try await post(endpoint: "/auth/v1/verify", body: body, requiresAuth: false)
    }

    func validateSession(token: String) async throws -> UserProfile {
        let response: SupabaseUser = try await get(endpoint: "/auth/v1/user", token: token)
        let profile = UserProfile(supabaseId: response.id, email: response.email, phone: response.phone)
        profile.onboardingComplete = response.userMetadata?.onboardingComplete ?? false
        profile.sessionToken = token
        return profile
    }

    func signOut() async throws {
        guard let token = sessionToken else { return }
        let _: EmptyResponse = try await post(endpoint: "/auth/v1/logout", body: [:], token: token)
    }

    // MARK: - Athlete Profile Sync

    func upsertAthleteProfile(_ profile: AthleteProfile, token: String) async throws {
        let body: [String: Any] = [
            "user_id": profile.userId.uuidString,
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
        ]
        let _: EmptyResponse = try await post(
            endpoint: "/rest/v1/athlete_profiles?on_conflict=user_id",
            body: body,
            token: token,
            method: "PUT"
        )
    }

    // MARK: - Session Sync

    func syncSetLog(_ log: SetLog, exerciseSupabaseId: String, token: String) async throws {
        let body: [String: Any] = [
            "exercise_id": exerciseSupabaseId,
            "set_number": log.setNumber,
            "actual_weight_kg": log.actualWeightKg,
            "actual_reps": log.actualReps,
            "rpe_actual": log.rpeActual,
            "logged_at": ISO8601DateFormatter().string(from: log.loggedAt)
        ]
        let _: EmptyResponse = try await post(endpoint: "/rest/v1/set_logs", body: body, token: token)
    }

    func markSessionComplete(supabaseSessionId: String, token: String) async throws {
        let body: [String: Any] = [
            "status": "completed",
            "completed_at": ISO8601DateFormatter().string(from: Date())
        ]
        let _: EmptyResponse = try await post(
            endpoint: "/rest/v1/training_sessions?id=eq.\(supabaseSessionId)",
            body: body,
            token: token,
            method: "PATCH"
        )
    }

    // MARK: - Chat Messages Sync

    func syncChatMessage(_ message: ChatMessage, token: String) async throws {
        let body: [String: Any] = [
            "user_id": message.userId.uuidString,
            "role": message.role,
            "content": message.content,
            "flagged_injury": message.flaggedInjury,
            "flagged_exercise_swap": message.flaggedExerciseSwap,
            "created_at": ISO8601DateFormatter().string(from: message.createdAt)
        ]
        let _: EmptyResponse = try await post(endpoint: "/rest/v1/chat_messages", body: body, token: token)
    }

    // MARK: - HTTP Helpers

    private func post<T: Decodable>(
        endpoint: String,
        body: [String: Any],
        requiresAuth: Bool = true,
        token: String? = nil,
        method: String = "POST"
    ) async throws -> T {
        guard let url = URL(string: supabaseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")

        let authToken = token ?? sessionToken
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func get<T: Decodable>(endpoint: String, token: String? = nil) async throws -> T {
        guard let url = URL(string: supabaseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")

        let authToken = token ?? sessionToken
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Supporting Types

enum APIError: LocalizedError {
    case invalidURL
    case serverError(Int)
    case decodingError
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .serverError(let code): return "Server error: \(code)"
        case .decodingError: return "Failed to decode response"
        case .unauthorized: return "Session expired. Please sign in again."
        }
    }
}

struct EmptyResponse: Codable {}

struct SupabaseUser: Codable {
    let id: String
    let email: String?
    let phone: String?
    let userMetadata: UserMetadata?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case phone
        case userMetadata = "user_metadata"
    }
}

struct UserMetadata: Codable {
    let onboardingComplete: Bool?
    enum CodingKeys: String, CodingKey {
        case onboardingComplete = "onboarding_complete"
    }
}
