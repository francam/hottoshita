import SwiftUI

struct CheckInFlowView: View {
    @State private var answers = CheckInAnswers()
    @State private var step = 0
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appTheme: AppTheme

    // Steps: 0=sleep, 1=feeling, 2=bp-yn, 3=bp-input (conditional), summary
    private var totalSteps: Int { answers.tookBloodPressure ? 4 : 3 }
    private var summaryStep: Int { answers.tookBloodPressure ? 4 : 3 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if step > 0 && step < summaryStep {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { step -= 1 }
                    } label: {
                        Label("Back", systemImage: "chevron.left").font(.title3)
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }.font(.title3)
            }
            .padding()

            if step < summaryStep {
                ProgressView(value: Double(step + 1), total: Double(totalSteps))
                    .tint(appTheme.accent)
                    .padding(.horizontal)
                    .padding(.bottom, 6)

                Text("Question \(step + 1) of \(totalSteps)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            }

            stepContent
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appTheme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            SingleChoiceStepView(
                question: "How was your sleep?",
                icon: "moon.zzz.fill",
                choices: SleepRating.allCases.map(\.rawValue),
                selection: Binding(
                    get: { answers.sleep.rawValue },
                    set: { answers.sleep = SleepRating(rawValue: $0) ?? .ok }
                )
            ) {
                withAnimation(.easeInOut(duration: 0.3)) { step = 1 }
            }
        case 1:
            MultiSelectStepView(
                question: "How are you feeling now?",
                icon: "face.smiling.inverse",
                options: feelingOptions,
                selections: $answers.feelings
            ) {
                withAnimation(.easeInOut(duration: 0.3)) { step = 2 }
            }
        case 2:
            YesNoStepView(
                question: "Can you take your blood pressure?",
                icon: "heart.fill",
                value: $answers.tookBloodPressure
            ) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    step = answers.tookBloodPressure ? 3 : summaryStep
                }
            }
        case 3 where answers.tookBloodPressure:
            BloodPressureStepView(bp: $answers.bloodPressure) {
                withAnimation(.easeInOut(duration: 0.3)) { step = summaryStep }
            }
        default:
            SummaryView(answers: answers) {
                withAnimation { answers = CheckInAnswers(); step = 0 }
            }
        }
    }
}

// MARK: - Single Choice

private struct SingleChoiceStepView: View {
    @EnvironmentObject private var appTheme: AppTheme
    let question: LocalizedStringKey
    let icon: String
    let choices: [String]
    @Binding var selection: String
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 48) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 64))
                    .foregroundStyle(appTheme.accent)
                Text(question)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal)
            }

            VStack(spacing: 18) {
                ForEach(choices, id: \.self) { choice in
                    Button {
                        selection = choice
                        Task {
                            try? await Task.sleep(for: .milliseconds(180))
                            onNext()
                        }
                    } label: {
                        Text(LocalizedStringKey(choice))
                            .font(.title2.bold())
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: 420)
                            .padding(.vertical, 24)
                            .background(
                                selection == choice ? appTheme.accent : Color(.systemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 18)
                            )
                            .foregroundStyle(selection == choice ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Multi Select

private struct MultiSelectStepView: View {
    @EnvironmentObject private var appTheme: AppTheme
    let question: LocalizedStringKey
    let icon: String
    let options: [String]
    @Binding var selections: [String]
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 64))
                    .foregroundStyle(appTheme.accent)
                Text(question)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal)
                Text("Select all that apply")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(options, id: \.self) { option in
                    Button {
                        if selections.contains(option) {
                            selections.removeAll { $0 == option }
                        } else {
                            selections.append(option)
                        }
                    } label: {
                        Text(LocalizedStringKey(option))
                            .font(.title3.bold())
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 26)
                            .background(
                                selections.contains(option) ? appTheme.accent : Color(.systemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .foregroundStyle(selections.contains(option) ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 48)

            Button(action: onNext) {
                Text(selections.isEmpty ? "Skip" : "Continue")
                    .font(.title3.bold())
                    .frame(maxWidth: 300)
                    .padding(.vertical, 18)
            }
            .buttonStyle(.borderedProminent)
            .tint(appTheme.accent)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Yes / No

private struct YesNoStepView: View {
    @EnvironmentObject private var appTheme: AppTheme
    let question: LocalizedStringKey
    let icon: String
    @Binding var value: Bool
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 48) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 64))
                    .foregroundStyle(appTheme.accent)
                Text(question)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal)
            }

            HStack(spacing: 16) {
                yesNoButton(key: "Yes", answer: true)
                yesNoButton(key: "No", answer: false)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func yesNoButton(key: LocalizedStringKey, answer: Bool) -> some View {
        Button {
            value = answer
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                onNext()
            }
        } label: {
            Text(key)
                .font(.title.bold())
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    value == answer ? appTheme.accent : Color(.systemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 22)
                )
                .foregroundStyle(value == answer ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Blood Pressure Input

private struct BloodPressureStepView: View {
    @EnvironmentObject private var appTheme: AppTheme
    @Binding var bp: BloodPressure
    let onNext: () -> Void

    @FocusState private var focusedField: Field?
    enum Field { case systolic, diastolic }

    var body: some View {
        VStack(spacing: 48) {
            VStack(spacing: 16) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 64))
                    .foregroundStyle(appTheme.accent)
                Text("Enter your blood pressure")
                    .font(.system(size: 36, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack(spacing: 24) {
                BPField(label: "Systolic\n(top)", value: $bp.systolic, focus: $focusedField, field: .systolic)
                Text("/")
                    .font(.largeTitle.weight(.light))
                    .foregroundStyle(.secondary)
                BPField(label: "Diastolic\n(bottom)", value: $bp.diastolic, focus: $focusedField, field: .diastolic)
            }
            .padding(.horizontal, 48)

            Button(action: onNext) {
                Text(bp.isValid ? "Continue" : "Skip")
                    .font(.title3.bold())
                    .frame(maxWidth: 300)
                    .padding(.vertical, 18)
            }
            .buttonStyle(.borderedProminent)
            .tint(appTheme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { focusedField = .systolic }
    }
}

private struct BPField: View {
    let label: String
    @Binding var value: String
    @FocusState.Binding var focus: BloodPressureStepView.Field?
    let field: BloodPressureStepView.Field

    var body: some View {
        VStack(spacing: 12) {
            TextField("---", text: $value)
                .font(.system(.largeTitle, design: .rounded).bold())
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .focused($focus, equals: field)
                .frame(minWidth: 120)
                .padding()
                .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
