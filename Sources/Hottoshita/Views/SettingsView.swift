import SwiftUI

struct SettingsView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @AppStorage("contactEmail") private var contactEmail = ""
    @EnvironmentObject private var appTheme: AppTheme

    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 9 * 60  // 09:00

    @State private var userNameInput = ""
    @State private var contactNameInput = ""
    @State private var emailInput = ""
    @State private var showContactPicker = false
    @State private var showNotificationsDenied = false
    @Environment(\.dismiss) private var dismiss

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: reminderMinutes / 60,
                    minute: reminderMinutes % 60,
                    second: 0, of: Date()
                ) ?? Date()
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                reminderMinutes = (c.hour ?? 9) * 60 + (c.minute ?? 0)
                if reminderEnabled {
                    ReminderScheduler.schedule(hour: c.hour ?? 9, minute: c.minute ?? 0)
                }
            }
        )
    }

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
                    Button {
                        showContactPicker = true
                    } label: {
                        Label("Choose from Contacts", systemImage: "person.crop.circle.badge.plus")
                            .font(.title3)
                    }
                    .foregroundStyle(appTheme.accent)
                }

                Section("Daily Reminder") {
                    Toggle("Remind me every day", isOn: $reminderEnabled)
                        .font(.title3)
                        .tint(appTheme.accent)
                    if reminderEnabled {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                            .font(.title3)
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
                    Button { dismiss() } label: {
                        Text("Cancel")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(appTheme.onAccent)
                            .padding(.horizontal, 2)
                            .fixedSize()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appTheme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: save) {
                        Text("Save")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(canSave ? appTheme.onAccent : Color.secondary)
                            .padding(.horizontal, 2)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appTheme.accent)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                userNameInput = userName
                contactNameInput = contactName
                emailInput = contactEmail
            }
            .onChange(of: reminderEnabled) { enabled in
                if enabled {
                    Task {
                        if await ReminderScheduler.requestAuthorization() {
                            ReminderScheduler.schedule(
                                hour: reminderMinutes / 60,
                                minute: reminderMinutes % 60
                            )
                        } else {
                            reminderEnabled = false
                            showNotificationsDenied = true
                        }
                    }
                } else {
                    ReminderScheduler.cancel()
                }
            }
            .alert("Notifications Disabled", isPresented: $showNotificationsDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please allow notifications for Hottoshita in the Settings app.")
            }
            .background(
                ContactPickerPresenter(isPresented: $showContactPicker) { pickedName, pickedEmail in
                    contactNameInput = pickedName
                    emailInput = pickedEmail
                }
            )
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
