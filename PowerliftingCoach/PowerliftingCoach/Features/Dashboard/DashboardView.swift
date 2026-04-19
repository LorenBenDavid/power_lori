import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) var modelContext
    @Query(sort: \TrainingProgram.generatedAt, order: .reverse) var programs: [TrainingProgram]

    var currentProgram: TrainingProgram? { programs.first(where: { $0.isCurrent }) }
    var currentSessions: [TrainingSession] { currentProgram?.sessions.sorted(by: { $0.dayNumber < $1.dayNumber }) ?? [] }

    var completedCount: Int { currentSessions.filter { $0.status == "completed" }.count }
    var streakCount: Int {
        // Count consecutive completed sessions backwards from today
        var streak = 0
        for session in currentSessions.reversed() where session.status == "completed" {
            streak += 1
        }
        return streak
    }

    var isWeekComplete: Bool { currentSessions.allSatisfy { $0.status == "completed" } }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        DashboardHeader(
                            firstName: authManager.currentUser?.athleteProfile?.firstName ?? "Athlete",
                            program: currentProgram
                        )

                        // Quick stats
                        QuickStatsRow(
                            completed: completedCount,
                            total: currentSessions.count,
                            streak: streakCount
                        )

                        // Session cards
                        VStack(alignment: .leading, spacing: 12) {
                            Text("This Week")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 24)

                            ForEach(currentSessions) { session in
                                NavigationLink(destination: SessionView(session: session)) {
                                    SessionCard(session: session)
                                        .padding(.horizontal, 24)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // End of week CTA
                        if isWeekComplete {
                            EndOfWeekBanner()
                                .padding(.horizontal, 24)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear { healSessionStatuses() }
    }

    /// Ensure sessions after a completed one are not stuck as "locked"
    private func healSessionStatuses() {
        guard let program = currentProgram else { return }
        let sorted = program.sessions.sorted { $0.dayNumber < $1.dayNumber }
        var changed = false
        for i in 0..<sorted.count - 1 {
            if sorted[i].status == "completed" && sorted[i + 1].status == "locked" {
                sorted[i + 1].status = "available"
                changed = true
            }
        }
        if changed { try? modelContext.save() }
    }
}

// MARK: - Dashboard Header

struct DashboardHeader: View {
    let firstName: String
    let program: TrainingProgram?

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Good \(timeOfDayGreeting), \(firstName)")
                    .font(.system(.title2, design: .rounded).weight(.bold))

                if let p = program {
                    Text("Week \(p.weekNumber) — \(p.blockType.blockDisplayName) Block")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Block badge
            if let block = program?.blockType {
                Text(block.blockDisplayName.uppercased())
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(block.blockColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(block.blockColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 24)
    }

    var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        default: return "evening"
        }
    }
}

// MARK: - Quick Stats Row

struct QuickStatsRow: View {
    let completed: Int
    let total: Int
    let streak: Int

    var body: some View {
        HStack(spacing: 12) {
            StatCard(value: "\(completed)/\(total)", label: "Sessions", icon: "checkmark.circle.fill", color: .appAccent)
            StatCard(value: "\(streak)", label: "Streak", icon: "flame.fill", color: .orange)
        }
        .padding(.horizontal, 24)
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: TrainingSession

    var statusColor: Color {
        switch session.status {
        case "completed": return .green
        case "in_progress": return .orange
        case "available": return Color.appAccent
        default: return .gray
        }
    }

    var statusIcon: String {
        switch session.status {
        case "completed": return "checkmark.circle.fill"
        case "in_progress": return "play.circle.fill"
        case "available": return "circle"
        default: return "lock.fill"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Day number
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text("D\(session.dayNumber)")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.mainLift.capitalized)
                    .font(.system(.body, design: .rounded).weight(.semibold))

                Text("\(session.exercises.count) exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundStyle(statusColor)
        }
        .padding(16)
        .glassCard()
        .opacity(session.status == "locked" ? 0.5 : 1.0)
    }
}

// MARK: - End of Week Banner

struct EndOfWeekBanner: View {
    @State private var showEndOfWeek = false

    var body: some View {
        Button {
            showEndOfWeek = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Color.appAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Week Complete!")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                    Text("Generate next week's program")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.appAccent.opacity(0.2), Color.appPurple.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.appAccent.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEndOfWeek) {
            EndOfWeekView()
                .presentationDetents([.large])
        }
    }
}
