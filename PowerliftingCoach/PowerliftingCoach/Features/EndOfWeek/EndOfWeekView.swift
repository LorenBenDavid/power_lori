import SwiftUI
import SwiftData

struct EndOfWeekView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \TrainingProgram.generatedAt, order: .reverse) var programs: [TrainingProgram]
    @State private var isGenerating = false
    @State private var showPreview = false
    @State private var nextProgram: ProgramResponse?
    @State private var errorMessage: String?

    var currentProgram: TrainingProgram? { programs.first(where: { $0.isCurrent }) }

    var weekSummary: WeekSummary? {
        guard let program = currentProgram else { return nil }
        return computeSummary(for: program)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Completion celebration
                        VStack(spacing: 16) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .orange.opacity(0.4), radius: 20)

                            Text("Week Complete!")
                                .font(.system(.title, design: .rounded).weight(.black))

                            if let p = currentProgram {
                                Text("Week \(p.weekNumber) — \(p.blockType.blockDisplayName) Block")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 32)

                        // Week stats
                        if let summary = weekSummary {
                            WeekSummaryGrid(summary: summary)
                                .padding(.horizontal, 24)
                        }

                        // Per-lift summary
                        if let summary = weekSummary {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Lift Summary")
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(.secondary)

                                ForEach(summary.liftStats, id: \.lift) { stat in
                                    LiftStatRow(stat: stat)
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        // Error
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        // Generate CTA
                        VStack(spacing: 12) {
                            Button {
                                Task { await generateNextWeek() }
                            } label: {
                                if isGenerating {
                                    HStack(spacing: 8) {
                                        ProgressView().tint(.white)
                                        Text("AI is building your program...")
                                    }
                                } else {
                                    Label("Generate Next Week's Program", systemImage: "sparkles")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(isGenerating)

                            Button("Maybe Later") { dismiss() }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("End of Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showPreview) {
                if let program = nextProgram {
                    NewProgramPreviewView(program: program) {
                        Task { await confirmNewProgram() }
                    }
                    .presentationDetents([.large])
                }
            }
        }
    }

    private func generateNextWeek() async {
        guard let profile = authManager.currentUser?.athleteProfile else { return }
        isGenerating = true
        errorMessage = nil

        // Build history from all programs
        let history = programs.prefix(12).compactMap { p -> WeekHistoryData? in
            guard let data = try? JSONDecoder().decode(ProgramResponse.self, from: p.programJson) else { return nil }
            return WeekHistoryData(
                weekNumber: p.weekNumber,
                block: p.blockType,
                sessions: p.sessions.map { session in
                    SessionHistoryData(
                        day: session.dayNumber,
                        mainLift: session.mainLift,
                        exercises: session.exercises.map { ex in
                            ExerciseHistoryData(
                                name: ex.exerciseName,
                                programmedSets: ex.programmedSets,
                                programmedReps: ex.programmedReps,
                                programmedWeightKg: ex.programmedWeightKg,
                                rpeTarget: ex.rpeTarget,
                                setLogs: ex.setLogs.map { log in
                                    SetLogHistoryData(
                                        setNumber: log.setNumber,
                                        actualWeightKg: log.actualWeightKg,
                                        actualReps: log.actualReps,
                                        rpeActual: log.rpeActual
                                    )
                                }
                            )
                        }
                    )
                }
            )
        }

        do {
            let response = try await AIService.shared.generateNextWeek(profile: profile, history: history)
            nextProgram = response
            isGenerating = false
            showPreview = true
        } catch {
            isGenerating = false
            errorMessage = "Could not generate program. Please check your connection and try again."
        }
    }

    private func confirmNewProgram() async {
        guard let response = nextProgram,
              let userId = authManager.currentUser?.id else { return }

        // Mark current program as not current
        currentProgram?.isCurrent = false

        let programData = (try? JSONEncoder().encode(response)) ?? Data()
        let program = TrainingProgram(
            userId: userId,
            weekNumber: response.weekNumber,
            blockType: response.block,
            programJson: programData
        )

        for (index, sessionData) in response.sessions.enumerated() {
            let session = TrainingSession(
                programId: program.id,
                userId: userId,
                dayNumber: sessionData.day,
                mainLift: sessionData.mainLift
            )
            session.status = index == 0 ? "available" : "locked"

            for (exIdx, exData) in sessionData.exercises.enumerated() {
                let exercise = SessionExercise(
                    sessionId: session.id,
                    exerciseName: exData.name,
                    programmedSets: exData.sets,
                    programmedReps: exData.reps,
                    programmedWeightKg: exData.weightKg,
                    rpeTarget: exData.rpeTarget,
                    notes: exData.notes,
                    orderIndex: exIdx
                )
                session.exercises.append(exercise)
                modelContext.insert(exercise)
            }

            program.sessions.append(session)
            modelContext.insert(session)
        }

        modelContext.insert(program)
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Summary Computation

    struct WeekSummary {
        let totalSessions: Int
        let totalVolume: Double
        let avgRPE: Double
        let liftStats: [LiftStat]
    }

    struct LiftStat {
        let lift: String
        let sessions: Int
        let avgRPE: Double
        let totalVolume: Double
    }

    private func computeSummary(for program: TrainingProgram) -> WeekSummary {
        let completedSessions = program.sessions.filter { $0.status == "completed" }
        let allLogs = completedSessions.flatMap { $0.exercises.flatMap(\.setLogs) }

        let totalVolume = allLogs.reduce(0.0) { $0 + $1.actualWeightKg * Double($1.actualReps) }
        let avgRPE = allLogs.isEmpty ? 0.0 : Double(allLogs.map(\.rpeActual).reduce(0, +)) / Double(allLogs.count)

        let lifts = ["Squat", "Bench Press", "Deadlift"]
        let liftStats = lifts.compactMap { lift -> LiftStat? in
            let sessions = completedSessions.filter { $0.mainLift.lowercased().contains(lift.lowercased()) }
            guard !sessions.isEmpty else { return nil }
            let logs = sessions.flatMap { $0.exercises.flatMap(\.setLogs) }
            let vol = logs.reduce(0.0) { $0 + $1.actualWeightKg * Double($1.actualReps) }
            let rpe = logs.isEmpty ? 0.0 : Double(logs.map(\.rpeActual).reduce(0, +)) / Double(logs.count)
            return LiftStat(lift: lift, sessions: sessions.count, avgRPE: rpe, totalVolume: vol)
        }

        return WeekSummary(
            totalSessions: completedSessions.count,
            totalVolume: totalVolume,
            avgRPE: avgRPE,
            liftStats: liftStats
        )
    }
}

// MARK: - Week Summary Grid

struct WeekSummaryGrid: View {
    let summary: EndOfWeekView.WeekSummary

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SummaryStatCard(
                    value: "\(summary.totalSessions)",
                    label: "Sessions",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                SummaryStatCard(
                    value: "\(Int(summary.totalVolume))kg",
                    label: "Total Volume",
                    icon: "scalemass.fill",
                    color: Color.appAccent
                )
            }

            SummaryStatCard(
                value: String(format: "%.1f", summary.avgRPE),
                label: "Avg RPE",
                icon: "gauge.high",
                color: Int(summary.avgRPE).rpeColor
            )
        }
    }
}

struct SummaryStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassCard()
    }
}

struct LiftStatRow: View {
    let stat: EndOfWeekView.LiftStat

    var body: some View {
        HStack {
            Text(stat.lift)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Avg RPE \(String(format: "%.1f", stat.avgRPE))")
                    .font(.caption)
                    .foregroundStyle(Int(stat.avgRPE).rpeColor)
                Text("\(Int(stat.totalVolume))kg vol")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - New Program Preview

struct NewProgramPreviewView: View {
    let program: ProgramResponse
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("Week \(program.weekNumber)")
                                .font(.system(.title2, design: .rounded).weight(.black))
                            Text(program.block.blockDisplayName + " Block")
                                .font(.subheadline)
                                .foregroundStyle(program.block.blockColor)
                        }
                        .padding(.top, 24)

                        // Coach notes
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Coach Notes", systemImage: "brain")
                                .font(.caption)
                                .foregroundStyle(Color.appPurple)
                            Text(program.coachNotes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .glassCard()
                        .padding(.horizontal, 24)

                        // Sessions preview
                        ForEach(program.sessions, id: \.day) { session in
                            SessionPreviewCard(session: session)
                                .padding(.horizontal, 24)
                        }

                        VStack(spacing: 12) {
                            Button("Start Week \(program.weekNumber)") {
                                onConfirm()
                                dismiss()
                            }
                            .buttonStyle(PrimaryButtonStyle())

                            Button("Cancel") { dismiss() }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Your New Program")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SessionPreviewCard: View {
    let session: SessionData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Day \(session.day) — \(session.mainLift.capitalized)")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                Spacer()
            }

            ForEach(session.exercises, id: \.name) { ex in
                HStack {
                    Text(ex.name)
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(ex.sets)×\(ex.reps) @ \(Int(ex.weightKg))kg")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("RPE\(ex.rpeTarget)")
                        .font(.caption2)
                        .foregroundStyle(ex.rpeTarget.rpeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ex.rpeTarget.rpeColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 14)
    }
}
