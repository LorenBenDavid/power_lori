import SwiftUI

struct EmailAuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var isValid: Bool {
        !email.isEmpty && password.count >= 6 && email.contains("@")
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                // Handle
                Capsule()
                    .frame(width: 40, height: 4)
                    .foregroundStyle(.secondary.opacity(0.4))
                    .padding(.top, 8)

                Text(isSignUp ? "Create Account" : "Sign In")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)

                VStack(spacing: 16) {
                    // Email field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email").font(.caption).foregroundStyle(.secondary)
                        TextField("athlete@email.com", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textContentType(.emailAddress)
                            .focused($focusedField, equals: .email)
                            .padding()
                            .glassCard(cornerRadius: 12)
                    }

                    // Password field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password").font(.caption).foregroundStyle(.secondary)
                        SecureField("At least 6 characters", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .focused($focusedField, equals: .password)
                            .padding()
                            .glassCard(cornerRadius: 12)
                    }
                }
                .padding(.horizontal, 24)

                // Error message
                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Submit button
                Button {
                    Task { await submit() }
                } label: {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isValid || isLoading)
                .padding(.horizontal, 24)

                // Toggle sign in / sign up
                Button {
                    withAnimation { isSignUp.toggle() }
                } label: {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.caption)
                        .foregroundStyle(Color.appAccent)
                }

                Spacer()
            }
        }
        .onAppear { focusedField = .email }
    }

    private func submit() async {
        isLoading = true
        defer { isLoading = false }

        if isSignUp {
            await authManager.signUpWithEmail(email: email, password: password)
        } else {
            await authManager.signInWithEmail(email: email, password: password)
        }

        if authManager.errorMessage == nil {
            dismiss()
        }
    }
}
