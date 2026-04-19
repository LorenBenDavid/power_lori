import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @State private var showEmailAuth = false
    @State private var showPhoneAuth = false
    @State private var authMode: AuthMode = .signIn

    enum AuthMode { case signIn, signUp }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                Spacer()

                // Logo & tagline
                VStack(spacing: 16) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: Color.appAccent.opacity(0.4), radius: 20, x: 0, y: 8)

                    VStack(spacing: 8) {
                        Text("PowerLori")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Your AI Powerlifting Coach")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Auth options
                VStack(spacing: 16) {
                    // Sign in with Apple
                    SignInWithAppleButton()

                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
                        Text("or").font(.caption).foregroundStyle(.secondary)
                        Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
                    }

                    // Email button
                    Button {
                        showEmailAuth = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                            Text("Continue with Email")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    // Phone/SMS button
                    Button {
                        showPhoneAuth = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "phone.fill")
                            Text("Continue with Phone")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPhoneAuth) {
            PhoneAuthView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Sign In With Apple Button

struct SignInWithAppleButton: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        SignInWithAppleButtonView()
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct SignInWithAppleButtonView: UIViewRepresentable {
    @EnvironmentObject var authManager: AuthManager

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleAppleSignIn), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(authManager: authManager)
    }

    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let authManager: AuthManager

        init(authManager: AuthManager) {
            self.authManager = authManager
        }

        @objc func handleAppleSignIn() {
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithAuthorization authorization: ASAuthorization
        ) {
            Task {
                await authManager.signInWithApple(authorization: authorization)
            }
        }

        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithError error: Error
        ) {
            Task { @MainActor in
                authManager.errorMessage = error.localizedDescription
            }
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? UIWindow()
        }
    }
}
