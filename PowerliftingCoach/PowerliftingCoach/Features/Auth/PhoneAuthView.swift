import SwiftUI

enum PhoneAuthStep { case enterPhone, enterOTP }

struct PhoneAuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var phone = ""
    @State private var otp = ""
    @State private var step: PhoneAuthStep = .enterPhone
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Capsule()
                    .frame(width: 40, height: 4)
                    .foregroundStyle(.secondary.opacity(0.4))
                    .padding(.top, 8)

                Text(step == .enterPhone ? "Enter Your Phone" : "Enter Code")
                    .font(.system(.title2, design: .rounded).weight(.bold))

                Text(step == .enterPhone
                    ? "We'll send a verification code to your phone"
                    : "Enter the 6-digit code sent to \(phone)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

                if step == .enterPhone {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Phone Number").font(.caption).foregroundStyle(.secondary)
                        TextField("+1 555 000 0000", text: $phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .padding()
                            .glassCard(cornerRadius: 12)
                    }
                    .padding(.horizontal, 24)
                } else {
                    OTPInputView(otp: $otp)
                        .padding(.horizontal, 24)
                }

                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task { await submitStep() }
                } label: {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(step == .enterPhone ? "Send Code" : "Verify")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(step == .enterPhone ? phone.isEmpty : otp.count < 6)
                .padding(.horizontal, 24)

                if step == .enterOTP {
                    Button {
                        step = .enterPhone
                        otp = ""
                    } label: {
                        Text("Change number")
                            .font(.caption)
                            .foregroundStyle(Color.appAccent)
                    }
                }

                Spacer()
            }
        }
    }

    private func submitStep() async {
        isLoading = true
        defer { isLoading = false }

        if step == .enterPhone {
            do {
                try await authManager.sendOTP(phone: phone)
                withAnimation { step = .enterOTP }
            } catch {
                authManager.errorMessage = error.localizedDescription
            }
        } else {
            await authManager.verifyOTP(phone: phone, token: otp)
            if authManager.errorMessage == nil {
                dismiss()
            }
        }
    }
}

// MARK: - OTP Input

struct OTPInputView: View {
    @Binding var otp: String
    private let length = 6
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $otp)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0)
                .onChange(of: otp) { _, new in
                    if new.count > length { otp = String(new.prefix(length)) }
                }

            HStack(spacing: 12) {
                ForEach(0..<length, id: \.self) { i in
                    let digit: String = otp.count > i ? String(otp[otp.index(otp.startIndex, offsetBy: i)]) : ""
                    Text(digit.isEmpty ? "—" : digit)
                        .font(.system(.title, design: .monospaced).weight(.bold))
                        .frame(width: 48, height: 56)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    otp.count == i ? Color.appAccent : Color.clear,
                                    lineWidth: 2
                                )
                        )
                }
            }
            .onTapGesture { focused = true }
        }
        .onAppear { focused = true }
    }
}
