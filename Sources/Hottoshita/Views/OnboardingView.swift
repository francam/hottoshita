import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appTheme: AppTheme
    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @AppStorage("contactEmail") private var contactEmail = ""

    @Environment(\.isCompactHeight) private var isCompactHeight

    @State private var step = 0
    @State private var userNameInput = ""
    @State private var contactNameInput = ""
    @State private var emailInput = ""

    // Steps: 0 = name, 1 = greeting splash (transient), 2 = contact,
    // 3 = daily reminder opt-in, 4 = colour.
    private var isSplash: Bool { step == 1 }
    private var dotIndex: Int { step == 0 ? 0 : step - 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots (hidden during the greeting splash)
            HStack(spacing: 10) {
                ForEach(0..<4) { i in
                    Circle()
                        .fill(i <= dotIndex ? appTheme.accent : Color.secondary.opacity(0.3))
                        .frame(width: i == dotIndex ? 12 : 8, height: i == dotIndex ? 12 : 8)
                        .animation(.easeInOut, value: step)
                }
            }
            .padding(.top, isCompactHeight ? 8 : 24)
            .padding(.bottom, 8)
            .opacity(isSplash ? 0 : 1)

            // Back button row (going back from contact skips the splash)
            HStack {
                if step > 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { step = step == 2 ? 0 : step - 1 }
                    } label: {
                        Label {
                            Text("Back")
                        } icon: {
                            Image(systemName: "chevron.left").accessibilityHidden(true)
                        }
                        .font(.title3)
                    }
                    .foregroundStyle(appTheme.accent)
                }
                Spacer()
            }
            .padding(.horizontal)
            .frame(height: 44)

            // Scrollable so the Continue button stays reachable when the
            // keyboard is up; content centres itself when there's room.
            // The contact step scrolls internally (its Continue button is
            // pinned to the bottom), so don't wrap it in another ScrollView.
            if step == 2 {
                stepContent
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appTheme.background.ignoresSafeArea())
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--debug-contact-picker") { step = 2 }
            #endif
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            OnboardingNameStep(value: $userNameInput, accent: appTheme.accent) {
                withAnimation(.easeInOut(duration: 0.3)) { step = 1 }
            }
        case 1:
            OnboardingGreetingSplash(name: userNameInput.trimmingCharacters(in: .whitespaces)) {
                withAnimation(.easeInOut(duration: 0.4)) { step = 2 }
            }
        case 2:
            OnboardingContactStep(
                name: $contactNameInput,
                email: $emailInput,
                accent: appTheme.accent
            ) {
                withAnimation(.easeInOut(duration: 0.3)) { step = 3 }
            }
        case 3:
            OnboardingReminderStep {
                withAnimation(.easeInOut(duration: 0.3)) { step = 4 }
            }
        default:
            OnboardingColorStep(appTheme: appTheme) {
                userName = userNameInput.trimmingCharacters(in: .whitespaces)
                contactName = contactNameInput.trimmingCharacters(in: .whitespaces)
                contactEmail = emailInput.trimmingCharacters(in: .whitespaces)
            }
        }
    }
}

// MARK: - Step 1: Name

private struct OnboardingNameStep: View {
    @EnvironmentObject private var appTheme: AppTheme
    @Binding var value: String
    let accent: Color
    let onNext: () -> Void

    @Environment(\.isCompactHeight) private var isCompactHeight

    var body: some View {
        AdaptiveStepLayout {
            StepHeader(
                icon: "person.circle.fill",
                question: "What's your name?",
                subtitle: "We'll use it to personalise your experience.",
                iconSize: 72
            )
        } controls: {
            VStack(spacing: isCompactHeight ? 16 : 40) {
                LabeledTextField(label: "Your Name", placeholder: "e.g. John", text: $value)

                Button(action: onNext) {
                    Text("Continue")
                        .font(.title2.bold())
                        .foregroundStyle(appTheme.onAccent)
                        .frame(maxWidth: 400)
                        .padding(.vertical, isCompactHeight ? 14 : 20)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(value.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, isCompactHeight ? 0 : 48)
        }
    }
}

// MARK: - Greeting splash (transient, auto-advances)

private struct OnboardingGreetingSplash: View {
    @EnvironmentObject private var appTheme: AppTheme
    let name: String
    let onFinish: () -> Void

    @State private var visible = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 88))
                .foregroundStyle(appTheme.accent)
                .accessibilityHidden(true)
            Text(String(format: NSLocalizedString("greeting.hi", comment: ""), name))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 32)
            Text("Let's get you set up.")
                .font(.title2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .scaleEffect(visible ? 1 : 0.8)
        .opacity(visible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.6)) { visible = true }
        }
        .task {
            try? await Task.sleep(for: .seconds(2.2))
            onFinish()
        }
    }
}

// MARK: - Step 2: Contact

private struct OnboardingContactStep: View {
    @EnvironmentObject private var appTheme: AppTheme
    @Binding var name: String
    @Binding var email: String
    let accent: Color
    let onNext: () -> Void

    @State private var showContactPicker = false

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@")
    }

    private var autoOpenPickerForDebug: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--debug-contact-picker")
        #else
        return false
        #endif
    }

    @Environment(\.isCompactHeight) private var isCompactHeight

    var body: some View {
        // The Continue button stays pinned at the bottom of the screen; only
        // the header/fields scroll (e.g. when the keyboard is up).
        Group {
            if isCompactHeight {
                HStack(spacing: 24) {
                    header
                        .frame(maxWidth: .infinity)
                    VStack(spacing: 12) {
                        ScrollView {
                            fields
                                .padding(.vertical, 4)
                        }
                        continueButton
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    GeometryReader { geo in
                        ScrollView {
                            VStack(spacing: 16) {
                                header
                                fields
                                    .padding(.horizontal, 48)
                            }
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, minHeight: geo.size.height)
                        }
                    }
                    continueButton
                        .padding(.horizontal, 48)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                }
            }
        }
        .background(
            ContactPickerPresenter(isPresented: $showContactPicker) { pickedName, pickedEmail in
                name = pickedName
                email = pickedEmail
            }
        )
        .onAppear {
            if autoOpenPickerForDebug {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showContactPicker = true }
            }
        }
    }

    private var header: some View {
        StepHeader(
            icon: "envelope.circle.fill",
            question: "Who receives your reports?",
            subtitle: "Your check-in will be emailed to them each day.",
            iconSize: 56
        )
    }

    private var fields: some View {
        VStack(spacing: isCompactHeight ? 10 : 16) {
            Button { showContactPicker = true } label: {
                Label {
                    Text("Choose from Contacts")
                } icon: {
                    Image(systemName: "person.crop.circle.badge.plus").accessibilityHidden(true)
                }
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, isCompactHeight ? 8 : 12)
            }
            .buttonStyle(.bordered)
            .tint(accent)

            Text("or enter the details yourself:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LabeledTextField(label: "Trusted Contact Name", placeholder: "e.g. Sarah", text: $name)
            LabeledTextField(label: "Email Address", placeholder: "e.g. sarah@example.com", text: $email, keyboardType: .emailAddress)
        }
    }

    private var continueButton: some View {
        Button(action: onNext) {
            Text("Continue")
                .font(.title2.bold())
                .foregroundStyle(appTheme.onAccent)
                .frame(maxWidth: 400)
                .padding(.vertical, isCompactHeight ? 10 : 20)
        }
        .buttonStyle(.borderedProminent)
        .tint(accent)
        .disabled(!canContinue)
    }
}

// MARK: - Step 3: Daily reminder (opt-in)

private struct OnboardingReminderStep: View {
    @EnvironmentObject private var appTheme: AppTheme
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 9 * 60
    let onNext: () -> Void

    @Environment(\.isCompactHeight) private var isCompactHeight

    @State private var wantsReminder = false
    @State private var pickedTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var showDenied = false

    var body: some View {
        AdaptiveStepLayout {
            StepHeader(
                icon: "bell.badge.fill",
                question: "Would you like a daily reminder?",
                subtitle: "We'll remind you to send your check-in.",
                iconSize: 72
            )
        } controls: {
            if wantsReminder {
                VStack(spacing: isCompactHeight ? 12 : 24) {
                    // The wheel is far too tall for landscape; use the
                    // compact picker there.
                    if isCompactHeight {
                        DatePicker("Time", selection: $pickedTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    } else {
                        DatePicker("Time", selection: $pickedTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                    }

                    Button(action: enableReminder) {
                        Text("Set Reminder")
                            .font(.title2.bold())
                            .foregroundStyle(appTheme.onAccent)
                            .frame(maxWidth: 400)
                            .padding(.vertical, isCompactHeight ? 14 : 20)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appTheme.accent)

                    Button("Not now") { declineAndContinue() }
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, isCompactHeight ? 0 : 48)
            } else {
                VStack(spacing: isCompactHeight ? 12 : 16) {
                    Button { withAnimation { wantsReminder = true } } label: {
                        Label {
                            Text("Yes, remind me")
                        } icon: {
                            Image(systemName: "bell.fill").accessibilityHidden(true)
                        }
                        .font(.title2.bold())
                        .foregroundStyle(appTheme.onAccent)
                        .frame(maxWidth: 400)
                        .padding(.vertical, isCompactHeight ? 14 : 20)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appTheme.accent)

                    Button { declineAndContinue() } label: {
                        Text("Not now")
                            .font(.title3.bold())
                            .frame(maxWidth: 400)
                            .padding(.vertical, isCompactHeight ? 12 : 16)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                }
                .padding(.horizontal, isCompactHeight ? 0 : 48)
            }
        }
        .alert("Notifications Disabled", isPresented: $showDenied) {
            Button("OK", role: .cancel) { onNext() }
        } message: {
            Text("You can turn reminders on later in Settings.")
        }
    }

    private func enableReminder() {
        Task {
            if await ReminderScheduler.requestAuthorization() {
                let c = Calendar.current.dateComponents([.hour, .minute], from: pickedTime)
                reminderMinutes = (c.hour ?? 9) * 60 + (c.minute ?? 0)
                reminderEnabled = true
                ReminderScheduler.schedule(hour: c.hour ?? 9, minute: c.minute ?? 0)
                onNext()
            } else {
                reminderEnabled = false
                showDenied = true
            }
        }
    }

    private func declineAndContinue() {
        reminderEnabled = false
        onNext()
    }
}

// MARK: - Step 4: Color

private struct OnboardingColorStep: View {
    @ObservedObject var appTheme: AppTheme
    let onFinish: () -> Void

    @Environment(\.isCompactHeight) private var isCompactHeight

    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        AdaptiveStepLayout {
            StepHeader(
                icon: "paintpalette.fill",
                question: "Choose your background",
                subtitle: "Pick a colour that feels right for you.",
                iconSize: 72
            )
        } controls: {
            VStack(spacing: isCompactHeight ? 16 : 40) {
                LazyVGrid(columns: columns, spacing: isCompactHeight ? 12 : 20) {
                    ForEach(ColorTheme.allCases, id: \.self) { theme in
                        colorSwatch(theme)
                    }
                }

                Button {
                    appTheme.updateAppIcon()
                    onFinish()
                } label: {
                    Text("Get Started")
                        .font(.title2.bold())
                        .foregroundStyle(appTheme.onAccent)
                        .frame(maxWidth: 400)
                        .padding(.vertical, isCompactHeight ? 12 : 20)
                }
                .buttonStyle(.borderedProminent)
                .tint(appTheme.accent)
            }
            .padding(.horizontal, isCompactHeight ? 0 : 48)
        }
    }

    private func colorSwatch(_ theme: ColorTheme) -> some View {
        let selected = appTheme.theme == theme
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { appTheme.theme = theme }
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(theme.color)
                    .frame(width: 52, height: 52)
                    .overlay(Circle().stroke(selected ? appTheme.accent : Color.secondary.opacity(0.3), lineWidth: selected ? 3 : 1))
                    .overlay(selected ? Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(appTheme.accent).accessibilityHidden(true) : nil)
                Text(theme.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Shared text field

struct LabeledTextField: View {
    let label: LocalizedStringKey
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.title3.bold())
            TextField(placeholder, text: $text)
                .font(.title3)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                .autocorrectionDisabled(keyboardType == .emailAddress)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
