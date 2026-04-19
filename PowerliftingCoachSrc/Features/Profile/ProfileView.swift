import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showSignOutConfirm = false
    @State private var showEditProfile = false

    var profile: AthleteProfile? { authManager.currentUser?.athleteProfile }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                List {
                    // Athlete info
                    Section {
                        if let p = profile {
                            HStack(spacing: 16) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 56))
                                    .foregroundStyle(Color.appAccent)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(p.firstName) \(p.lastName)")
                                        .font(.system(.title3, design: .rounded).weight(.bold))
                                    Text(p.experienceLevel.capitalized + " Powerlifter")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("\(p.weightKg, format: .number.precision(.fractionLength(1)))kg · \(Int(p.heightCm))cm · \(p.age) yrs")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))

                    // Training details
                    if let p = profile {
                        Section("Training") {
                            ProfileRow(label: "Goal", value: p.goal.capitalized, icon: "target")
                            ProfileRow(label: "Days/Week", value: "\(p.trainingDaysPerWeek)x", icon: "calendar")
                            ProfileRow(label: "Focus Lifts", value: p.focusLifts.joined(separator: ", "), icon: "bolt.fill")
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }

                    // Settings
                    Section("Settings") {
                        Button {
                            showEditProfile = true
                        } label: {
                            ProfileRow(label: "Edit Profile", value: "", icon: "pencil", chevron: true)
                        }

                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            ProfileRow(label: "Notifications", value: "", icon: "bell.fill", chevron: false)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))

                    // Account
                    Section("Account") {
                        Button(role: .destructive) {
                            showSignOutConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundStyle(.red)
                                Text("Sign Out")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))

                    // App version
                    Section {
                        HStack {
                            Spacer()
                            Text("PL.AI v1.0.0 · iOS 17+")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .confirmationDialog(
            "Sign Out",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task { await authManager.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .presentationDetents([.large])
        }
    }
}

struct ProfileRow: View {
    let label: String
    let value: String
    let icon: String
    var chevron = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.appAccent)
                .frame(width: 28)

            Text(label)
                .font(.system(.body, design: .rounded))

            Spacer()

            if !value.isEmpty {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if chevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Edit Profile

struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var weightKg = ""
    @State private var goal = ""

    let goals = ["Strength", "Bulk", "Cut"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Form {
                    Section("Body Weight") {
                        TextField("kg", text: $weightKg)
                            .keyboardType(.decimalPad)
                    }
                    .listRowBackground(Color.white.opacity(0.05))

                    Section("Goal") {
                        Picker("Goal", selection: $goal) {
                            ForEach(goals, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let p = authManager.currentUser?.athleteProfile {
                weightKg = String(format: "%.1f", p.weightKg)
                goal = p.goal
            }
        }
    }

    private func saveChanges() {
        guard let p = authManager.currentUser?.athleteProfile else { return }
        if let w = Double(weightKg) { p.weightKg = w }
        if !goal.isEmpty { p.goal = goal }
        p.updatedAt = Date()
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @State private var workoutReminders = true
    @State private var reminderTime = Date()
    @State private var streakReminders = true

    var body: some View {
        ZStack {
            AppBackground()

            List {
                Section {
                    Toggle("Workout Reminders", isOn: $workoutReminders)
                    if workoutReminders {
                        DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                    Toggle("Streak Reminders", isOn: $streakReminders)
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
    }
}
