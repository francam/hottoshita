import CloudKit
import SwiftUI

struct SettingsView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @AppStorage("contactEmail") private var contactEmail = ""
    @AppStorage(TrustedContacts.storageKey) private var additionalContactsJSON = ""
    @EnvironmentObject private var appTheme: AppTheme
    @EnvironmentObject private var store: CheckInStore

    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 9 * 60  // 09:00

    @State private var userNameInput = ""
    /// Everyone who receives the report, staged until Save like the rest.
    @State private var contactsInput: [TrustedContact] = []
    @State private var showAddChoice = false
    @State private var showAddSheet = false
    @State private var editingContact: TrustedContact?
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
        !userNameInput.trimmingCharacters(in: .whitespaces).isEmpty && !contactsInput.isEmpty
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

                Section {
                    ForEach(contactsInput) { contact in
                        contactRow(contact)
                    }
                    if contactsInput.count < TrustedContacts.maximum {
                        Button { showAddChoice = true } label: {
                            Label("Add Contact", systemImage: "plus.circle.fill")
                                .font(.title3)
                        }
                        .foregroundStyle(appTheme.accent)
                        .confirmationDialog(Text("Add Contact"), isPresented: $showAddChoice, titleVisibility: .visible) {
                            Button("Choose from Contacts") { showContactPicker = true }
                            Button("Type a Contact") { showAddSheet = true }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                } header: {
                    Text("Trusted Contacts")
                } footer: {
                    Text("contacts.footer")
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
                contactsInput = TrustedContacts.list(primaryName: contactName, primaryEmail: contactEmail,
                                                     additionalJSON: additionalContactsJSON)
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
                    addContact(TrustedContact(name: pickedName, email: pickedEmail))
                }
            )
            .sheet(isPresented: $showAddSheet) {
                AddContactSheet(onAdd: addContact).environmentObject(appTheme)
            }
            .sheet(item: $editingContact) { contact in
                AddContactSheet(editing: contact) { edited in
                    if let i = contactsInput.firstIndex(where: { $0.id == edited.id }) {
                        contactsInput[i] = edited
                    }
                }
                .environmentObject(appTheme)
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

    /// Tap to edit; an explicit remove button rather than swipe-to-delete,
    /// which elderly users rarely discover. The last contact can't be
    /// removed — Save needs at least one.
    private func contactRow(_ contact: TrustedContact) -> some View {
        HStack(spacing: 12) {
            Button { editingContact = contact } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name).font(.title3).foregroundStyle(.primary)
                    Text(contact.email).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Double-tap to edit."))

            if contactsInput.count > 1 {
                Button(role: .destructive) {
                    contactsInput.removeAll { $0.id == contact.id }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Remove \(contact.name)"))
            }
        }
    }

    /// Someone already in the list (same email) isn't added twice.
    private func addContact(_ contact: TrustedContact) {
        let email = contact.email.lowercased()
        guard contactsInput.count < TrustedContacts.maximum,
              !contactsInput.contains(where: { $0.email.lowercased() == email }) else { return }
        contactsInput.append(contact)
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
        let contacts = TrustedContacts.split(contactsInput)
        contactName = contacts.name
        contactEmail = contacts.email
        additionalContactsJSON = contacts.additionalJSON

        reminderEnabled = reminderEnabledInput
        reminderMinutes = reminderMinutesInput
        if reminderEnabledInput {
            ReminderScheduler.scheduleNext(hour: reminderMinutesInput / 60, minute: reminderMinutesInput % 60, submittedToday: store.submittedToday)
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
