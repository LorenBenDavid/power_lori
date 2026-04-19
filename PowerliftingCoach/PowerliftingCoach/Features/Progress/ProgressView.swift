import SwiftUI
import SwiftData
import Charts

struct TrainingProgressView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) var modelContext
    @Query(sort: \TrainingProgram.generatedAt) var programs: [TrainingProgram]
    @State private var selectedLift = "Squat"

    let lifts = ["Squat", "Bench Press", "Deadlift"]

    // Estimated 1RM = weight × (1 + reps/30) — Epley formula
    func estimated1RM(weight: Double, reps: Int) -> Double {
        weight * (1 + Double(reps) / 30.0)
    }

    struct PRDataPoint: Identifiable {
        let id = UUID()
        let week: Int
        let estimatedMax: Double
        let lift: String
    }

    var prData: [PRDataPoint] {
        var points: [PRDataPoint] = []
        for program in programs {
            guard let data = try? JSONDecoder().decode(ProgramResponse.self, from: program.programJson) else { continue }
            for session in (program.sessions) {
                for exercise in session.exercises {
                    guard exercise.exerciseName.lowercased().contains(selectedLift.lowercased().components(separatedBy: " ").first ?? "") else { continue }
                    if let bestLog = exercise.setLogs.max(by: { estimated1RM(weight: $0.actualWeightKg, reps: $0.actualReps) < estimated1RM(weight: $1.actualWeightKg, reps: $1.actualReps) }) {
                        let e1rm = estimated1RM(weight: bestLog.actualWeightKg, reps: bestLog.actualReps)
                        points.append(PRDataPoint(week: program.weekNumber, estimatedMax: e1rm, lift: selectedLift))
                    }
                }
            }
        }
        return points.sorted(by: { $0.week < $1.week })
    }

    // Average RPE per week
    struct RPEPoint: Identifiable {
        let id = UUID()
        let week: Int
        let avgRPE: Double
    }

    var rpeData: [RPEPoint] {
        programs.compactMap { program in
            let allLogs = program.sessions.flatMap { $0.exercises.flatMap { $0.setLogs } }
            guard !allLogs.isEmpty else { return nil }
            let avg = Double(allLogs.map(\.rpeActual).reduce(0, +)) / Double(allLogs.count)
            return RPEPoint(week: program.weekNumber, avgRPE: avg)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Lift selector
                        Picker("Lift", selection: $selectedLift) {
                            ForEach(lifts, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)

                        // Estimated 1RM chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Estimated 1RM – \(selectedLift)")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.secondary)

                            if prData.isEmpty {
                                EmptyChartPlaceholder(message: "Complete sessions to see your progress")
                            } else {
                                Chart(prData) { point in
                                    LineMark(
                                        x: .value("Week", point.week),
                                        y: .value("e1RM (kg)", point.estimatedMax)
                                    )
                                    .foregroundStyle(Color.appAccent)
                                    .interpolationMethod(.catmullRom)

                                    AreaMark(
                                        x: .value("Week", point.week),
                                        y: .value("e1RM (kg)", point.estimatedMax)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.appAccent.opacity(0.3), Color.appAccent.opacity(0)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)

                                    PointMark(
                                        x: .value("Week", point.week),
                                        y: .value("e1RM (kg)", point.estimatedMax)
                                    )
                                    .foregroundStyle(Color.appAccent)
                                    .symbolSize(60)
                                }
                                .chartXAxis {
                                    AxisMarks(values: .automatic) { value in
                                        AxisValueLabel { Text("W\(value.as(Int.self) ?? 0)") }
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(values: .automatic) { value in
                                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0)kg") }
                                    }
                                }
                                .frame(height: 200)
                            }
                        }
                        .padding(16)
                        .glassCard()
                        .padding(.horizontal, 16)

                        // RPE Trend chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Average RPE per Week")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.secondary)

                            if rpeData.isEmpty {
                                EmptyChartPlaceholder(message: "Log sessions to see RPE trends")
                            } else {
                                Chart(rpeData) { point in
                                    BarMark(
                                        x: .value("Week", point.week),
                                        y: .value("Avg RPE", point.avgRPE)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Int(point.avgRPE).rpeColor, Int(point.avgRPE).rpeColor.opacity(0.5)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .cornerRadius(6)
                                }
                                .chartYScale(domain: 0...11)
                                .chartXAxis {
                                    AxisMarks(values: .automatic) { value in
                                        AxisValueLabel { Text("W\(value.as(Int.self) ?? 0)") }
                                    }
                                }
                                .frame(height: 160)
                            }
                        }
                        .padding(16)
                        .glassCard()
                        .padding(.horizontal, 16)

                        // Session history
                        SessionHistoryList(programs: programs)
                            .padding(.horizontal, 16)

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Empty Chart Placeholder

struct EmptyChartPlaceholder: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session History List

struct SessionHistoryList: View {
    let programs: [TrainingProgram]

    var completedSessions: [(session: TrainingSession, weekNumber: Int)] {
        programs.flatMap { program in
            program.sessions.filter { $0.status == "completed" }.map { ($0, program.weekNumber) }
        }
        .sorted { a, b in
            (a.session.completedAt ?? .distantPast) > (b.session.completedAt ?? .distantPast)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session History")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)

            if completedSessions.isEmpty {
                Text("No completed sessions yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(20)
            } else {
                VStack(spacing: 8) {
                    ForEach(completedSessions.prefix(20), id: \.session.id) { item in
                        HistorySessionRow(session: item.session, weekNumber: item.weekNumber)
                    }
                }
            }
        }
    }
}

struct HistorySessionRow: View {
    let session: TrainingSession
    let weekNumber: Int

    var totalVolume: Double {
        session.exercises.flatMap(\.setLogs)
            .reduce(0) { $0 + ($1.actualWeightKg * Double($1.actualReps)) }
    }

    var avgRPE: Double {
        let logs = session.exercises.flatMap(\.setLogs)
        guard !logs.isEmpty else { return 0 }
        return Double(logs.map(\.rpeActual).reduce(0, +)) / Double(logs.count)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Week \(weekNumber) · \(session.mainLift.capitalized)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))

                if let date = session.completedAt {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(totalVolume))kg vol")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Avg RPE \(String(format: "%.1f", avgRPE))")
                    .font(.caption2)
                    .foregroundStyle(Int(avgRPE).rpeColor)
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 10)
    }
}
