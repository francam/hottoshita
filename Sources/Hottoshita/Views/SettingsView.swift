import SwiftUI

struct SettingsView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @AppStorage("contactEmail") private var contactEmail = ""
    @EnvironmentObject private var appTheme: AppTheme

    @State private var userNameInput = ""
    @State private var contactNameInput = ""
    @State private var emailInput = ""
    @Environment(\.dismiss) private var dismiss

    private var canSave: Bool {
        !userNameInput.trimmingCharacters(in: .whitespaces).isEmpty &&
        !contactNameInput.trimmingCharacters(in: .whitespaces).isEmpty &&
        emailInput.contains("@")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("About You") {
                    formRow(label: "Your Name") {
                        TextField("Your name", text: $userNameInput)
                            .font(.title3)
                            .textInputAutocapitalization(.words)
                    }
                }

                Section("Trusted Contact") {
                    formRow(label: "Name") {
                        TextField("Contact name", text: $contactNameInput)
                            .font(.title3)
                    }
                    formRow(label: "Email") {
                        TextField("Contact email", text: $emailInput)
                            .font(.title3)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section("Background Colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(ColorTheme.allCases, id: \.self) { theme in
                            colorSwatch(theme)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(appTheme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .bold()
                        .disabled(!canSave)
                }
            }
            .onAppear {
                userNameInput = userName
                contactNameInput = contactName
                emailInput = contactEmail
            }
        }
        .background(appTheme.background.ignoresSafeArea())
    }

    private func colorSwatch(_ theme: ColorTheme) -> some View {
        let selected = appTheme.theme == theme
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { appTheme.theme = theme }
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(theme.color)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle().stroke(selected ? appTheme.accent : Color.secondary.opacity(0.3), lineWidth: selected ? 3 : 1)
                    )
                    .overlay(
                        selected ? Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(appTheme.accent) : nil
                    )
                Text(theme.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func formRow(label: LocalizedStringKey, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            field()
        }
        .padding(.vertical, 4)
    }

    private func save() {
        userName = userNameInput.trimmingCharacters(in: .whitespaces)
        contactName = contactNameInput.trimmingCharacters(in: .whitespaces)
        contactEmail = emailInput.trimmingCharacters(in: .whitespaces)
        dismiss()
    }
}
