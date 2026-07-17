import SwiftUI

struct CheckInFlowView: View {
    @State private var answers = CheckInAnswers()
    @State private var step = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isCompactHeight) private var isCompactHeight
    @EnvironmentObject private var appTheme: AppTheme

    // Steps: 0=sleep, 1=feeling, 2=bp-yn, 3=bp-input (conditional), summary
    private var totalSteps: Int { (answers.tookBloodPressure ?? false) ? 4 : 3 }
    private var summaryStep: Int { (answers.tookBloodPressure ?? false) ? 4 : 3 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if step > 0 && step < summaryStep {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { step -= 1 }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(appTheme.accent)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .font(.title3.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.bordered)
                .tint(appTheme.accent)
            }
            .padding(.horizontal)
            .padding(.vertical, isCompactHeight ? 6 : 16)

            if step < summaryStep {
                ProgressView(value: Double(step + 1), total: Double(totalSteps))
                    .tint(appTheme.accent)
                    .padding(.horizontal)
                    .padding(.bottom, 6)

                Text("Question \(step + 1) of \(totalSteps)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, isCompactHeight ? 8 : 24)
            }

            // Portrait: scrollable as a safety net for very large text sizes;
            // content centres itself when there's room. Compact height pins
            // the step to the screen instead — steps are laid out to fit, and
            // the feelings grid scrolls internally.
            // The summary step brings its own ScrollView, so don't nest it.
            if step < summaryStep, isCompactHeight {
                stepContent
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .padding(.vertical, 8)
            } else if step < summaryStep {
                GeometryReader { geo in
                    ScrollView {
                        stepContent
                            .id(step)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity, minHeight: geo.size.height)
                    }
                }
            } else {
                stepContent
                    .id(step)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
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
                    get: { answers.sleep?.rawValue ?? "" },
                    set: { answers.sleep = SleepRating(rawValue: $0) }
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
                    step = (answers.tookBloodPressure ?? false) ? 3 : summaryStep
                }
            }
        case 3 where answers.tookBloodPressure == true:
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
    @Environment(\.isCompactHeight) private var isCompactHeight
    @EnvironmentObject private var appTheme: AppTheme
    let question: LocalizedStringKey
    let icon: String
    let choices: [String]
    @Binding var selection: String
    let onNext: () -> Void

    var body: some View {
        AdaptiveStepLayout(spacing: 48) {
            StepHeader(icon: icon, question: question)
        } controls: {
            VStack(spacing: isCompactHeight ? 12 : 18) {
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
                            .padding(.vertical, isCompactHeight ? 12 : 24)
                            .background(
                                selection == choice ? appTheme.accent : Color(.systemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 18)
                            )
                            .foregroundStyle(selection == choice ? appTheme.onAccent : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, isCompactHeight ? 0 : 48)
        }
    }
}

// MARK: - Multi Select

private struct MultiSelectStepView: View {
    @Environment(\.isCompactHeight) private var isCompactHeight
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appTheme: AppTheme
    let question: LocalizedStringKey
    let icon: String
    let options: [String]
    @Binding var selections: [String]
    let onNext: () -> Void

    var body: some View {
        AdaptiveStepLayout {
            StepHeader(icon: icon, question: question, subtitle: "Select all that apply")
        } controls: {
            if isCompactHeight {
                // Only the options may scroll; the Skip/Continue button
                // stays fixed below them.
                VStack(spacing: 12) {
                    ScrollView {
                        optionsGrid
                    }
                    nextButton
                }
            } else {
                VStack(spacing: 40) {
                    optionsGrid
                    nextButton
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 48)
            }
        }
    }

    /// iPad is wide enough for 4 across, which halves the grid's height so
    /// the step fits landscape without scrolling. iPhone keeps 2 columns.
    private var gridColumns: [GridItem] {
        let count = horizontalSizeClass == .regular && !isCompactHeight ? 4 : 2
        return Array(repeating: GridItem(.flexible()), count: count)
    }

    private var optionsGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: isCompactHeight ? 10 : 16) {
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
                        .padding(.vertical, isCompactHeight ? 12 : 26)
                        .background(
                            selections.contains(option) ? appTheme.accent : Color(.systemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .foregroundStyle(selections.contains(option) ? appTheme.onAccent : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var nextButton: some View {
        Button(action: onNext) {
            Text(selections.isEmpty ? "Skip" : "Continue")
                .font(.title3.bold())
                .foregroundStyle(appTheme.onAccent)
                .frame(maxWidth: 300)
                .padding(.vertical, isCompactHeight ? 12 : 18)
        }
        .buttonStyle(.borderedProminent)
        .tint(appTheme.accent)
    }
}

// MARK: - Yes / No

private struct YesNoStepView: View {
    @Environment(\.isCompactHeight) private var isCompactHeight
    @EnvironmentObject private var appTheme: AppTheme
    let question: LocalizedStringKey
    let icon: String
    @Binding var value: Bool?
    let onNext: () -> Void

    var body: some View {
        AdaptiveStepLayout(spacing: 48) {
            StepHeader(icon: icon, question: question)
        } controls: {
            HStack(spacing: 16) {
                yesNoButton(key: "Yes", answer: true)
                yesNoButton(key: "No", answer: false)
            }
            .padding(.horizontal, isCompactHeight ? 0 : 32)
        }
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
                .padding(.vertical, isCompactHeight ? 20 : 32)
                .background(
                    value == answer ? appTheme.accent : Color(.systemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 22)
                )
                .foregroundStyle(value == answer ? appTheme.onAccent : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Blood Pressure Input

private struct BloodPressureStepView: View {
    @Environment(\.isCompactHeight) private var isCompactHeight
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appTheme: AppTheme
    @Binding var bp: BloodPressure
    let onNext: () -> Void

    @FocusState private var focusedField: Field?
    enum Field { case systolic, diastolic }

    /// The number pad has no dismiss key, so it stays up for this whole
    /// step — shrink the header so the fields and button fit above it.
    private var keyboardUp: Bool { focusedField != nil }

    var body: some View {
        // iPad keyboards are tall enough (especially landscape) that the
        // stacked layout can't fit above them — go side-by-side instead.
        AdaptiveStepLayout(spacing: keyboardUp ? 24 : 48,
                           forceSideBySide: keyboardUp && horizontalSizeClass == .regular) {
            StepHeader(icon: "waveform.path.ecg", question: "Enter your blood pressure",
                       showIcon: isCompactHeight || !keyboardUp)
        } controls: {
            VStack(spacing: isCompactHeight ? 16 : keyboardUp ? 24 : 48) {
                // Fields flex to share the width; a hard minimum here would
                // overflow an iPhone screen in portrait and clip the step.
                HStack(spacing: 16) {
                    BPField(label: "Systolic\n(top)", value: $bp.systolic, focus: $focusedField, field: .systolic)
                    Text("/")
                        .font(.largeTitle.weight(.light))
                        .foregroundStyle(.secondary)
                    BPField(label: "Diastolic\n(bottom)", value: $bp.diastolic, focus: $focusedField, field: .diastolic)
                }
                .frame(maxWidth: 420)
                .padding(.horizontal, isCompactHeight ? 0 : 24)

                Button(action: onNext) {
                    Text(bp.isValid ? "Continue" : "Skip")
                        .font(.title3.bold())
                        .foregroundStyle(appTheme.onAccent)
                        .frame(maxWidth: 300)
                        .padding(.vertical, isCompactHeight ? 12 : 18)
                }
                .buttonStyle(.borderedProminent)
                .tint(appTheme.accent)
            }
        }
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
                .frame(maxWidth: .infinity)
                .onChange(of: value) { newValue in
                    // Digits only (hardware keyboards / paste), max 3.
                    let cleaned = String(newValue.filter(\.isNumber).prefix(3))
                    if cleaned != newValue { value = cleaned }
                }
                .padding()
                .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
