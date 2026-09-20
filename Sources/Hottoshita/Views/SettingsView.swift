import CloudKit
import SwiftUI

struct SettingsView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @AppStorage("contactEmail") private var contactEmail = ""
    @EnvironmentObject private var appTheme: AppTheme
    @EnvironmentObject private var store: CheckInStore

    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 9 * 60  // 09:00

    @State private var userNameInput = ""
    @State private var contactNameInput = ""
    @State private var emailInput = ""
    @State private var reminderEnabledInput = false
    @State private var reminderMinutesInput = 9 * 60
    @State private var iCloudSyncInput = false
    @State private var showContactPicker = false
    @State private var showNotificationsDenied = false
    @State private var showiCloudSyncUnavailable = false
    // Background colour still applies live as swatches are tapped (so the
    // whole app previews the choice), but Cancel restores this so browsing
    // swatches isn't itself a commit.
    @State private var originalTheme: ColorTheme = .default
    // `onAppear` assigns into `reminderEnabledInput`/`iCloudSyncInput` from
    // stored state, which would otherwise trigger their `onChange` handlers
    // as if the user had just flipped the toggle. Guards those handlers
    // until the initial load has finished.
    @State private var hasLoadedInitialState = false
    @Environment(\.dismiss) private var dismiss

    // Staged the same way as the name/contact fields above — bound directly
    // to @AppStorage, this used to write (and reschedule the real
    // notification) the instant the user touched it, so Cancel couldn't
    // undo it. Only `save()` should commit reminder changes.
    private var reminderTimeInput: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: reminderMinutesInput / 60,
                    minute: reminderMinutesInput % 60,
                    second: 0, of: Date()
                ) ?? Date()
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                reminderMinutesInput = (c.hour ?? 9) * 60 + (c.minute ?? 0)
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
                        Label {
                            Text("Choose from Contacts")
                        } icon: {
                            Image(systemName: "person.crop.circle.badge.plus").accessibilityHidden(true)
                        }
                        .font(.title3)
                    }
                    .foregroundStyle(appTheme.accent)
                }

                Section("Daily Reminder") {
                    Toggle("Remind me every day", isOn: $reminderEnabledInput)
                        .font(.title3)
                        .tint(appTheme.accent)
                    if reminderEnabledInput {
                        DatePicker("Time", selection: reminderTimeInput, displayedComponents: .hourAndMinute)
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

                Section {
                    Toggle("Sync between your devices", isOn: $iCloudSyncInput)
                        .font(.title3)
                        .tint(appTheme.accent)
                } header: {
                    Text("iCloud Sync")
                } footer: {
                    Text("sync.description")
                }
            }
            .scrollContentBackground(.hidden)
            .background(appTheme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appTheme.theme = originalTheme
                        dismiss()
                    } label: {
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
                reminderEnabledInput = reminderEnabled
                reminderMinutesInput = reminderMinutes
                originalTheme = appTheme.theme
                iCloudSyncInput = iCloudSettingsSync.shared.isEnabled
                hasLoadedInitialState = true
            }
            .onChange(of: reminderEnabledInput) { enabled in
                // Only the permission prompt happens live — actually
                // scheduling or cancelling the notification is deferred to
                // save() so Cancel can still back out of this.
                guard hasLoadedInitialState else { return }
                if enabled {
                    Task {
                        if !(await ReminderScheduler.requestAuthorization()) {
                            reminderEnabledInput = false
                            showNotificationsDenied = true
                        }
                    }
                }
            }
            .onChange(of: iCloudSyncInput) { enabled in
                // Same pattern as the reminder toggle above: only check
                // account availability live, actually turning sync on is
                // deferred to save() so Cancel can still back out.
                guard hasLoadedInitialState, enabled else { return }
                Task {
                    let status = try? await CKContainer(identifier: "iCloud.com.hottoshita.app").accountStatus()
                    if status != .available {
                        iCloudSyncInput = false
                        showiCloudSyncUnavailable = true
                    }
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
            .alert("iCloud Sync Unavailable", isPresented: $showiCloudSyncUnavailable) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please sign in to iCloud in the Settings app to sync between your devices.")
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
                        selected ? Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(appTheme.accent).accessibilityHidden(true) : nil
                    )
                Text(theme.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
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

        reminderEnabled = reminderEnabledInput
        reminderMinutes = reminderMinutesInput
        if reminderEnabledInput {
            ReminderScheduler.schedule(hour: reminderMinutesInput / 60, minute: reminderMinutesInput % 60)
        } else {
            ReminderScheduler.cancel()
        }

        if iCloudSyncInput != iCloudSettingsSync.shared.isEnabled {
            iCloudSettingsSync.shared.isEnabled = iCloudSyncInput
            if iCloudSyncInput {
                // Backfill: push everything already on this device up, and
                // pull down anything already synced from another device.
                let entriesToPush = store.entries
                Task {
                    CheckInCloudSync.shared.pushAll(entriesToPush)
                    await store.syncWithCloud()
                }
            }
        }

        dismiss()
    }
}
