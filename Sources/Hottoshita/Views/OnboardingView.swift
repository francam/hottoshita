import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appTheme: AppTheme
    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @AppStorage("contactEmail") private var contactEmail = ""

    @State private var step = 0
    @State private var userNameInput = ""
    @State private var contactNameInput = ""
    @State private var emailInput = ""

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 10) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(i <= step ? appTheme.accent : Color.secondary.opacity(0.3))
                        .frame(width: i == step ? 12 : 8, height: i == step ? 12 : 8)
                        .animation(.easeInOut, value: step)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 8)

            // Back button row
            HStack {
                if step > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { step -= 1 }
                    } label: {
                        Label("Back", systemImage: "chevron.left").font(.title3)
                    }
                    .foregroundStyle(appTheme.accent)
                }
                Spacer()
            }
            .padding(.horizontal)
            .frame(height: 44)

            Spacer()

            stepContent
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appTheme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            OnboardingNameStep(value: $userNameInput, accent: appTheme.accent) {
                withAnimation(.easeInOut(duration: 0.3)) { step = 1 }
            }
        case 1:
            OnboardingContactStep(
                name: $contactNameInput,
                email: $emailInput,
                accent: appTheme.accent
            ) {
                withAnimation(.easeInOut(duration: 0.3)) { step = 2 }
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
    @Binding var value: String
    let accent: Color
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(accent)
                Text("What's your name?")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("We'll use it to personalise your experience.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            LabeledTextField(label: "Your Name", placeholder: "e.g. John", text: $value)
                .padding(.horizontal, 48)

            Button(action: onNext) {
                Text("Continue")
                    .font(.title2.bold())
                    .frame(maxWidth: 400)
                    .padding(.vertical, 20)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .disabled(value.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 48)
        }
    }
}

// MARK: - Step 2: Contact

private struct OnboardingContactStep: View {
    @Binding var name: String
    @Binding var email: String
    let accent: Color
    let onNext: () -> Void

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@")
    }

    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                Image(systemName: "envelope.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(accent)
                Text("Who receives your reports?")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Your check-in will be emailed to them each day.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            VStack(spacing: 20) {
                LabeledTextField(label: "Trusted Contact Name", placeholder: "e.g. Sarah", text: $name)
                LabeledTextField(label: "Email Address", placeholder: "e.g. sarah@example.com", text: $email, keyboardType: .emailAddress)
            }
            .padding(.horizontal, 48)

            Button(action: onNext) {
                Text("Continue")
                    .font(.title2.bold())
                    .frame(maxWidth: 400)
                    .padding(.vertical, 20)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .disabled(!canContinue)
            .padding(.horizontal, 48)
        }
    }
}

// MARK: - Step 3: Color

private struct OnboardingColorStep: View {
    @ObservedObject var appTheme: AppTheme
    let onFinish: () -> Void

    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(appTheme.accent)
                Text("Choose your background")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Pick a colour that feels right for you.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(ColorTheme.allCases, id: \.self) { theme in
                    colorSwatch(theme)
                }
            }
            .padding(.horizontal, 48)

            Button(action: onFinish) {
                Text("Get Started")
                    .font(.title2.bold())
                    .frame(maxWidth: 400)
                    .padding(.vertical, 20)
            }
            .buttonStyle(.borderedProminent)
            .tint(appTheme.accent)
            .padding(.horizontal, 48)
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
                    .overlay(selected ? Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(appTheme.accent) : nil)
                Text(theme.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
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
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
