import SwiftUI
import SwiftData

struct SessionView: View {
    @Bindable var session: TrainingSession
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var expandedExercise: UUID?
    @State private var showCompleteConfirm = false
    @State private var showRestTimer = false
    @State private var restSeconds = 180

    var allExercisesLogged: Bool {
        session.exercises.allSatisfy { ex in
            ex.setLogs.count >= ex.programmedSets && ex.setLogs.allSatisfy { $0.rpeActual > 0 }
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 16) {
                    // Session header
                    SessionHeader(session: session)

                    // RPE Guide (first session)
                    RPEGuideCard()

                    // Exercise list
                    ForEach(session.exercises.sorted(by: { $0.orderIndex < $1.orderIndex })) { exercise in
                        ExerciseAccordion(
                            exercise: exercise,
                            isExpanded: expandedExercise == exercise.id,
                            onToggle: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    expandedExercise = expandedExercise == exercise.id ? nil : exercise.id
                                }
                            },
                            onSetLogged: {
                                showRestTimer = true
                            },
                            modelContext: modelContext
                        )
                        .padding(.horizontal, 16)
                    }

                    // Complete button
                    Button {
                        showCompleteConfirm = true
                    } label: {
                        Label("Complete Workout", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!allExercisesLogged)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .padding(.top, 16)
            }

            // Rest timer overlay
            if showRestTimer {
                RestTimerOverlay(seconds: restSeconds) {
                    showRestTimer = false
                }
            }
        }
        .navigationTitle(session.mainLift.capitalized)
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Complete this workout?",
            isPresented: $showCompleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Complete Workout") { completeWorkout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Make sure you've logged all sets and RPE ratings.")
        }
        .onAppear {
            if session.status == "available" {
                session.status = "in_progress"
                session.startedAt = Date()
                try? modelContext.save()
            }
        }
    }

    private func completeWorkout() {
        session.status = "completed"
        session.completedAt = Date()
        session.pendingSync = true

        // Unlock next session
        if let program = session.exercises.first.flatMap({ _ in
            // Get the parent program via userId query
            return nil as TrainingProgram?
        }) {
            unlockNextSession(in: program)
        }

        try? modelContext.save()
        dismiss()
    }

    private func unlockNextSession(in program: TrainingProgram) {
        let sorted = program.sessions.sorted { $0.dayNumber < $1.dayNumber }
        if let idx = sorted.firstIndex(where: { $0.id == session.id }),
           idx + 1 < sorted.count {
            sorted[idx + 1].status = "available"
        }
    }
}

// MARK: - Session Header

struct SessionHeader: View {
    let session: TrainingSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Day \(session.dayNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(session.mainLift.capitalized + " Day")
                    .font(.system(.title3, design: .rounded).weight(.bold))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.exercises.count) exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                StatusBadge(status: session.status)
            }
        }
        .padding(16)
        .glassCard()
        .padding(.horizontal, 16)
    }
}

struct StatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "completed": return .green
        case "in_progress": return .orange
        case "available": return Color.appAccent
        default: return .gray
        }
    }

    var body: some View {
        Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Exercise Accordion

struct ExerciseAccordion: View {
    @Bindable var exercise: SessionExercise
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSetLogged: () -> Void
    let modelContext: ModelContext

    var logsCompleted: Int { exercise.setLogs.count }
    var isFullyLogged: Bool { logsCompleted >= exercise.programmedSets }

    var body: some View {
        VStack(spacing: 0) {
            // Header tap area
            Button(action: onToggle) {
                HStack(spacing: 14) {
                    // Completion indicator
                    ZStack {
                        Circle()
                            .fill(isFullyLogged ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Image(systemName: isFullyLogged ? "checkmark" : "\(logsCompleted + 1).circle")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(isFullyLogged ? .green : Color.appAccent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.exerciseName)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.primary)

                        HStack(spacing: 8) {
                            Text("\(exercise.programmedSets)×\(exercise.programmedReps)")
                            Text("@")
                            Text("\(Int(exercise.programmedWeightKg))kg")
                            Text("RPE \(exercise.rpeTarget)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(logsCompleted)/\(exercise.programmedSets)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Expanded set logger
            if isExpanded {
                Divider().opacity(0.2)

                VStack(spacing: 12) {
                    // Notes
                    if let notes = exercise.notes, !notes.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(Color.appAccent)
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                    }

                    // Logged sets
                    ForEach(exercise.setLogs.sorted(by: { $0.setNumber < $1.setNumber })) { log in
                        LoggedSetRow(log: log, setNumber: log.setNumber)
                    }

                    // New set logger (if not done)
                    if !isFullyLogged {
                        SetLoggerRow(
                            setNumber: logsCompleted + 1,
                            defaultWeight: exercise.programmedWeightKg,
                            defaultReps: exercise.programmedReps,
                            rpeTarget: exercise.rpeTarget
                        ) { weight, reps, rpe in
                            logSet(weight: weight, reps: reps, rpe: rpe)
                            onSetLogged()
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .glassCard(cornerRadius: 14)
    }

    private func logSet(weight: Double, reps: Int, rpe: Int) {
        let log = SetLog(
            exerciseId: exercise.id,
            setNumber: logsCompleted + 1,
            actualWeightKg: weight,
            actualReps: reps,
            rpeActual: rpe
        )
        exercise.setLogs.append(log)
        modelContext.insert(log)
        try? modelContext.save()
    }
}

// MARK: - Logged Set Row

struct LoggedSetRow: View {
    let log: SetLog
    let setNumber: Int

    var body: some View {
        HStack {
            Text("Set \(setNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            Text("\(Int(log.actualWeightKg))kg × \(log.actualReps)")
                .font(.system(.subheadline, design: .rounded).weight(.medium))

            Spacer()

            Text("RPE \(log.rpeActual)")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(log.rpeActual.rpeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(log.rpeActual.rpeColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 10)
    }
}

// MARK: - Set Logger Row

struct SetLoggerRow: View {
    let setNumber: Int
    let defaultWeight: Double
    let defaultReps: Int
    let rpeTarget: Int
    let onLog: (Double, Int, Int) -> Void

    @State private var weight: String
    @State private var reps: String
    @State private var rpe: Double

    init(setNumber: Int, defaultWeight: Double, defaultReps: Int, rpeTarget: Int, onLog: @escaping (Double, Int, Int) -> Void) {
        self.setNumber = setNumber
        self.defaultWeight = defaultWeight
        self.defaultReps = defaultReps
        self.rpeTarget = rpeTarget
        self.onLog = onLog
        _weight = State(initialValue: String(format: "%.1f", defaultWeight))
        _reps = State(initialValue: "\(defaultReps)")
        _rpe = State(initialValue: Double(rpeTarget))
    }

    var isValid: Bool {
        Double(weight) != nil && Int(reps) != nil && rpe >= 1
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Set \(setNumber)")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.appAccent)
                Spacer()
            }
            .padding(.horizontal, 14)

            HStack(spacing: 12) {
                // Weight field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weight (kg)").font(.caption2).foregroundStyle(.secondary)
                    TextField("0.0", text: $weight)
                        .keyboardType(.decimalPad)
                        .padding(8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .font(.system(.body, design: .monospaced))
                }

                // Reps field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reps").font(.caption2).foregroundStyle(.secondary)
                    TextField("0", text: $reps)
                        .keyboardType(.numberPad)
                        .padding(8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .font(.system(.body, design: .monospaced))
                }
            }
            .padding(.horizontal, 14)

            // RPE slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("RPE")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(rpe))")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Int(rpe).rpeColor)
                }

                Slider(value: $rpe, in: 1...11, step: 1)
                    .tint(Int(rpe).rpeColor)

                HStack {
                    Text("Easy").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("Max").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("Failed").font(.caption2).foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 14)

            Button("Log Set \(setNumber)") {
                guard let w = Double(weight), let r = Int(reps) else { return }
                onLog(w, r, Int(rpe))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!isValid)
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 12)
        .background(Color.appAccent.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 10)
    }
}

// MARK: - Rest Timer Overlay

struct RestTimerOverlay: View {
    let seconds: Int
    let onDismiss: () -> Void

    @State private var remaining: Int
    @State private var timer: Timer?

    init(seconds: Int, onDismiss: @escaping () -> Void) {
        self.seconds = seconds
        self.onDismiss = onDismiss
        _remaining = State(initialValue: seconds)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 24) {
                Text("Rest")
                    .font(.system(.title2, design: .rounded).weight(.bold))

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 140, height: 140)

                    Circle()
                        .trim(from: 0, to: CGFloat(remaining) / CGFloat(seconds))
                        .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: remaining)

                    Text(timeString)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                }

                HStack(spacing: 16) {
                    Button("Skip") { onDismiss() }
                        .buttonStyle(SecondaryButtonStyle())

                    Button(remaining == 0 ? "Done!" : "Done") { onDismiss() }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(32)
            .glassCard(material: .regularMaterial)
            .padding(.horizontal, 40)
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    var timeString: String {
        "\(remaining / 60):\(String(format: "%02d", remaining % 60))"
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remaining > 0 { remaining -= 1 }
            else { timer?.invalidate() }
        }
    }
}

// MARK: - RPE Guide Card

struct RPEGuideCard: View {
    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation { isExpanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: isExpanded ? 12 : 0) {
                HStack {
                    Label("RPE Guide", systemImage: "info.circle")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        RPEGuideRow(range: "1–5", meaning: "Very easy – could do many more reps")
                        RPEGuideRow(range: "6–7", meaning: "Moderate – a few reps in reserve")
                        RPEGuideRow(range: "8–9", meaning: "Hard – 1–2 reps left in the tank")
                        RPEGuideRow(range: "10", meaning: "Maximum – no reps left")
                        RPEGuideRow(range: "11", meaning: "Failed the rep")
                    }
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 12)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}

struct RPEGuideRow: View {
    let range: String
    let meaning: String

    var body: some View {
        HStack(spacing: 8) {
            Text("RPE \(range)")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle((Int(range.prefix(2)) ?? 7).rpeColor)
                .frame(width: 64, alignment: .leading)
            Text(meaning)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
