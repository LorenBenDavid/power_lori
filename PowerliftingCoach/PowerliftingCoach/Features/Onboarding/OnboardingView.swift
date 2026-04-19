import SwiftUI
import SwiftData

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) var modelContext
    @StateObject private var vm = OnboardingViewModel()

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Progress bar
                OnboardingProgressBar(current: vm.currentStep, total: vm.totalSteps)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                // Card carousel
                ZStack {
                    ForEach(0..<vm.totalSteps, id: \.self) { index in
                        if index == vm.currentStep {
                            OnboardingCard(step: index, vm: vm)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: vm.direction == .forward ? .trailing : .leading),
                                        removal: .move(edge: vm.direction == .forward ? .leading : .trailing)
                                    )
                                )
                        }
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: vm.currentStep)
                .padding(.horizontal, 24)

                Spacer()

                // Navigation buttons
                HStack(spacing: 16) {
                    if vm.currentStep > 0 {
                        Button("Back") {
                            vm.goBack()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: .infinity)
                    }

                    Button(vm.isLastStep ? "Submit" : "Next") {
                        if vm.isLastStep {
                            Task { await vm.submit(authManager: authManager, modelContext: modelContext) }
                        } else {
                            vm.goNext()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!vm.isCurrentStepValid || vm.isLoading)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }

            // Loading overlay
            if vm.isLoading {
                LoadingOverlay(message: "Generating your first program...")
            }
        }
        .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
}

// MARK: - Progress Bar

struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    var progress: Double { Double(current + 1) / Double(total) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(current + 1) of \(total)")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(Color.appAccent)

                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .glassCard(material: .regularMaterial)
            .padding(.horizontal, 40)
        }
    }
}
