import Foundation
import AuthenticationServices
import SwiftData
import Combine

enum AppState: Equatable {
    case loading
    case unauthenticated
    case onboarding
    case authenticated
}

@MainActor
final class AuthManager: NSObject, ObservableObject {
    @Published var appState: AppState = .loading
    @Published var currentUser: UserProfile?
    @Published var errorMessage: String?

    private let supabaseService = SupabaseService.shared
    private var modelContext: ModelContext?

    override init() {
        super.init()
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Session Restoration

    func restoreSession() async {
        guard let tokenData = KeychainManager.load(key: "session_token"),
              let token = String(data: tokenData, encoding: .utf8) else {
            appState = .unauthenticated
            return
        }

        do {
            var activeToken = token
            // Try to validate; if expired, refresh automatically
            let remoteUser: UserProfile
            do {
                remoteUser = try await supabaseService.validateSession(token: token)
            } catch APIError.serverError(let code) where code == 401 || code == 403 {
                guard let refreshData = KeychainManager.load(key: "refresh_token"),
                      let refreshToken = String(data: refreshData, encoding: .utf8) else {
                    KeychainManager.delete(key: "session_token")
                    appState = .unauthenticated
                    return
                }
                let refreshed = try await supabaseService.refreshSession(refreshToken: refreshToken)
                activeToken = refreshed.accessToken
                if let tokenData = activeToken.data(using: .utf8) {
                    KeychainManager.save(key: "session_token", data: tokenData)
                }
                if let newRefresh = refreshed.refreshToken, let rd = newRefresh.data(using: .utf8) {
                    KeychainManager.save(key: "refresh_token", data: rd)
                }
                remoteUser = try await supabaseService.validateSession(token: activeToken)
            }
            let token = activeToken

            // Always prefer the SwiftData record — it has onboardingComplete + all local data
            if let ctx = modelContext {
                let supabaseId = remoteUser.supabaseId
                let descriptor = FetchDescriptor<UserProfile>(
                    predicate: #Predicate { $0.supabaseId == supabaseId }
                )
                if let existing = try? ctx.fetch(descriptor).first {
                    existing.sessionToken = token
                    try? ctx.save()
                    currentUser = existing
                    appState = existing.onboardingComplete ? .authenticated : .onboarding
                    return
                }
            }

            // No local record yet — use remote (new install / new device)
            remoteUser.sessionToken = token
            modelContext?.insert(remoteUser)
            try? modelContext?.save()
            currentUser = remoteUser
            appState = remoteUser.onboardingComplete ? .authenticated : .onboarding
        } catch {
            KeychainManager.delete(key: "session_token")
            appState = .unauthenticated
        }
    }

    // MARK: - Sign In with Apple

    func signInWithApple(authorization: ASAuthorization) async {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            errorMessage = "Apple Sign-In failed: invalid credentials"
            return
        }

        do {
            let response = try await supabaseService.signInWithApple(
                identityToken: identityToken,
                fullName: appleCredential.fullName
            )
            await handleAuthSuccess(response: response)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Email Auth

    func signUpWithEmail(email: String, password: String) async {
        do {
            let response = try await supabaseService.signUpWithEmail(email: email, password: password)
            await handleAuthSuccess(response: response)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithEmail(email: String, password: String) async {
        do {
            let response = try await supabaseService.signInWithEmail(email: email, password: password)
            await handleAuthSuccess(response: response)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - SMS OTP

    func sendOTP(phone: String) async throws {
        try await supabaseService.sendOTP(phone: phone)
    }

    func verifyOTP(phone: String, token: String) async {
        do {
            let response = try await supabaseService.verifyOTP(phone: phone, token: token)
            await handleAuthSuccess(response: response)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await supabaseService.signOut()
        } catch {
            // Continue even if server sign out fails
        }
        KeychainManager.delete(key: "session_token")
        currentUser = nil
        appState = .unauthenticated
    }

    // MARK: - Onboarding Complete

    func completeOnboarding() {
        currentUser?.onboardingComplete = true
        appState = .authenticated
    }

    // MARK: - Private

    private func handleAuthSuccess(response: AuthResponse) async {
        if response.confirmationPending {
            errorMessage = "Check your email and click the confirmation link, then sign in."
            return
        }

        if let tokenData = response.accessToken.data(using: .utf8) {
            KeychainManager.save(key: "session_token", data: tokenData)
        }
        if let refresh = response.refreshToken, let refreshData = refresh.data(using: .utf8) {
            KeychainManager.save(key: "refresh_token", data: refreshData)
        }

        // Look up existing user in SwiftData by supabaseId
        if let ctx = modelContext {
            let supabaseId = response.userId
            let descriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate { $0.supabaseId == supabaseId }
            )
            if let existing = try? ctx.fetch(descriptor).first {
                // Returning user — update token and reuse all existing data
                existing.sessionToken = response.accessToken
                try? ctx.save()
                currentUser = existing
                appState = existing.onboardingComplete ? .authenticated : .onboarding
                return
            }
        }

        // New user — create and insert
        let user = UserProfile(
            supabaseId: response.userId,
            email: response.email,
            phone: response.phone
        )
        user.sessionToken = response.accessToken
        user.onboardingComplete = response.onboardingComplete
        modelContext?.insert(user)
        try? modelContext?.save()
        currentUser = user
        appState = response.onboardingComplete ? .authenticated : .onboarding
    }
}

// MARK: - Keychain Manager

enum KeychainManager {
    static func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Auth Response Model

// Supabase returns two shapes:
// 1. Signed in:  { "access_token": "...", "user": { "id": "...", ... } }
// 2. Confirmation pending: { "id": "...", "email": "...", ... }  (no access_token)
struct AuthResponse: Decodable {
    let accessToken: String       // empty string when confirmation pending
    let refreshToken: String?
    let confirmationPending: Bool
    let userId: String
    let email: String?
    let phone: String?
    let onboardingComplete: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)

        if container.contains(.accessToken) {
            // Shape 1: signed-in session
            accessToken = try container.decode(String.self, forKey: .accessToken)
            refreshToken = try? container.decode(String.self, forKey: .refreshToken)
            confirmationPending = false
            let user = try container.decode(SupabaseAuthUser.self, forKey: .user)
            userId = user.id
            email = user.email
            phone = (user.phone?.isEmpty ?? true) ? nil : user.phone
            onboardingComplete = user.userMetadata?.onboardingComplete ?? false
        } else {
            // Shape 2: email confirmation pending — user object is the root
            accessToken = ""
            refreshToken = nil
            confirmationPending = true
            userId = try container.decode(String.self, forKey: .id)
            email = try? container.decode(String.self, forKey: .email)
            phone = nil
            onboardingComplete = false
        }
    }

    private enum DynamicKey: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
        case id
        case email
    }
}

struct SupabaseAuthUser: Codable {
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
