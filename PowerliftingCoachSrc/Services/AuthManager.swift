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

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        Task { await restoreSession() }
    }

    // MARK: - Session Restoration

    func restoreSession() async {
        guard let tokenData = KeychainManager.load(key: "session_token"),
              let token = String(data: tokenData, encoding: .utf8) else {
            appState = .unauthenticated
            return
        }

        do {
            let user = try await supabaseService.validateSession(token: token)
            currentUser = user
            appState = user.onboardingComplete ? .authenticated : .onboarding
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
        if let tokenData = response.accessToken.data(using: .utf8) {
            KeychainManager.save(key: "session_token", data: tokenData)
        }

        let user = UserProfile(
            supabaseId: response.userId,
            email: response.email,
            phone: response.phone
        )
        user.sessionToken = response.accessToken
        user.onboardingComplete = response.onboardingComplete

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

struct AuthResponse: Codable {
    let userId: String
    let accessToken: String
    let email: String?
    let phone: String?
    let onboardingComplete: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case accessToken = "access_token"
        case email
        case phone
        case onboardingComplete = "onboarding_complete"
    }
}
