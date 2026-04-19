import SwiftUI

struct OnboardingCard: View {
    let step: Int
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    stepContent
                }
                .padding(28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassCard(cornerRadius: 24)
    }

    @ViewBuilder
    var stepContent: some View {
        switch step {
        case 0:
            TextInputCard(
                icon: "person.fill",
                title: "What's your first name?",
                subtitle: "Your coach will use this to personalize your program",
                placeholder: "First name",
                text: $vm.firstName
            )
        case 1:
            TextInputCard(
                icon: "person.fill",
                title: "And your last name?",
                subtitle: nil,
                placeholder: "Last name",
                text: $vm.lastName
            )
        case 2:
            SelectionCard(
                icon: "figure.stand",
                title: "What's your gender?",
                subtitle: "Used to tailor biomechanical recommendations",
                options: ["Male", "Female", "Other"],
                selection: $vm.gender
            )
        case 3:
            NumberInputCard(
                icon: "birthday.cake",
                title: "How old are you?",
                subtitle: "Must be 13 or older",
                placeholder: "e.g. 25",
                text: $vm.age,
                range: "13–80",
                keyboardType: .numberPad
            )
        case 4:
            NumberInputCard(
                icon: "scalemass",
                title: "Your body weight",
                subtitle: "In kilograms",
                placeholder: "e.g. 85",
                text: $vm.weightKg,
                range: "30–300 kg",
                keyboardType: .decimalPad
            )
        case 5:
            NumberInputCard(
                icon: "ruler",
                title: "Your height",
                subtitle: "In centimeters",
                placeholder: "e.g. 178",
                text: $vm.heightCm,
                range: "100–250 cm",
                keyboardType: .numberPad
            )
        case 6:
            SelectionCard(
                icon: "chart.bar.fill",
                title: "Training experience",
                subtitle: "How long have you been powerlifting?",
                options: ["Beginner", "Intermediate", "Advanced"],
                descriptions: [
                    "Beginner": "Less than 1 year",
                    "Intermediate": "1–3 years",
                    "Advanced": "3+ years, competed"
                ],
                selection: $vm.experienceLevel
            )
        case 7:
            SelectionCard(
                icon: "calendar",
                title: "Training days per week",
                subtitle: "How many days can you commit to the gym?",
                options: ["2", "3", "4", "5"],
                selection: $vm.trainingDaysPerWeek
            )
        case 8:
            SelectionCard(
                icon: "target",
                title: "What's your primary goal?",
                subtitle: "Your program structure will be built around this",
                options: ["Strength", "Bulk", "Cut"],
                descriptions: [
                    "Strength": "Maximize squat/bench/deadlift",
                    "Bulk": "Build muscle & strength",
                    "Cut": "Maintain strength in a caloric deficit"
                ],
                selection: $vm.goal
            )
        case 9:
            MultiSelectCard(
                icon: "bolt.fill",
                title: "Focus lifts",
                subtitle: "Select all lifts to train",
                options: ["Squat", "Bench Press", "Deadlift"],
                selection: $vm.focusLifts
            )
        case 10:
            SummaryCard(vm: vm)
        default:
            EmptyView()
        }
    }
}

// MARK: - Text Input Card

struct TextInputCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CardHeader(icon: icon, title: title, subtitle: subtitle)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding()
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(focused ? Color.appAccent : Color.white.opacity(0.15), lineWidth: 1.5)
                )
                .focused($focused)
                .keyboardType(keyboardType)
                .onAppear { focused = true }
        }
    }
}

// MARK: - Number Input Card

struct NumberInputCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let placeholder: String
    @Binding var text: String
    let range: String
    var keyboardType: UIKeyboardType = .numberPad
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CardHeader(icon: icon, title: title, subtitle: subtitle)

            VStack(alignment: .leading, spacing: 8) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(focused ? Color.appAccent : Color.white.opacity(0.15), lineWidth: 1.5)
                    )
                    .focused($focused)
                    .keyboardType(keyboardType)

                Text("Valid range: \(range)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { focused = true }
    }
}

// MARK: - Selection Card (single select)

struct SelectionCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let options: [String]
    var descriptions: [String: String] = [:]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CardHeader(icon: icon, title: title, subtitle: subtitle)

            VStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    SelectionOptionRow(
                        label: option,
                        description: descriptions[option],
                        isSelected: selection == option
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selection = option
                        }
                    }
                }
            }
        }
    }
}

struct SelectionOptionRow: View {
    let label: String
    let description: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(isSelected ? Color.appAccent : .primary)

                    if let desc = description {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.appAccent : .secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.appAccent.opacity(0.15) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.appAccent : Color.white.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Multi-Select Card

struct MultiSelectCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let options: [String]
    @Binding var selection: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CardHeader(icon: icon, title: title, subtitle: subtitle)

            VStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.contains(option)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if isSelected { selection.remove(option) }
                            else { selection.insert(option) }
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Text(option)
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .foregroundStyle(isSelected ? Color.appAccent : .primary)

                            Spacer()

                            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                .font(.title3)
                                .foregroundStyle(isSelected ? Color.appAccent : .secondary)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? Color.appAccent.opacity(0.15) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(isSelected ? Color.appAccent : Color.white.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CardHeader(
                icon: "checkmark.seal.fill",
                title: "Review your profile",
                subtitle: "Everything looks good? Tap Submit to generate your first program."
            )

            VStack(spacing: 8) {
                SummaryRow(label: "Name", value: "\(vm.firstName) \(vm.lastName)")
                SummaryRow(label: "Gender", value: vm.gender)
                SummaryRow(label: "Age", value: "\(vm.age) years")
                SummaryRow(label: "Weight", value: "\(vm.weightKg) kg")
                SummaryRow(label: "Height", value: "\(vm.heightCm) cm")
                SummaryRow(label: "Experience", value: vm.experienceLevel)
                SummaryRow(label: "Training Days", value: "\(vm.trainingDaysPerWeek)x / week")
                SummaryRow(label: "Goal", value: vm.goal)
                SummaryRow(label: "Focus Lifts", value: vm.focusLifts.sorted().joined(separator: ", "))
            }

            // Optional 1RM section
            VStack(alignment: .leading, spacing: 8) {
                Text("Optional: Current Max Lifts")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    MaxLiftField(label: "Squat", text: $vm.squatMaxKg)
                    MaxLiftField(label: "Bench", text: $vm.benchMaxKg)
                    MaxLiftField(label: "Deadlift", text: $vm.deadliftMaxKg)
                }
            }
        }
    }
}

struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
        Divider().opacity(0.2)
    }
}

struct MaxLiftField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            TextField("kg", text: $text)
                .keyboardType(.decimalPad)
                .padding(8)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .font(.system(.footnote, design: .monospaced))
        }
    }
}

// MARK: - Card Header

struct CardHeader: View {
    let icon: String
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.appAccent, Color.appPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
