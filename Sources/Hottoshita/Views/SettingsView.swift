import CloudKit
import SwiftUI

struct SettingsView: View {
    @State private var barsVertical = false
    @Environment(\.keepSheetToolbarHorizontal) private var keepSheetToolbarHorizontal
    @AppStorage("userName") private var userName = ""
    @AppStorage("contactName") private var contactName = ""
    @AppStorage("contactEmail") private var contactEmail = ""
    @AppStorage(TrustedContacts.storageKey) private var additionalContactsJSON = ""
    @EnvironmentObject private var appTheme: AppTheme
    @EnvironmentObject private var store: CheckInStore

    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 9 * 60  // 09:00

    @State private var userNameInput = ""
    @State private var contactsInput: [TrustedContact] = []
    @State private var contactsEditor = ContactsEditorState()
    @State private var reminderEnabledInput = false
    @State private var reminderMinutesInput = 9 * 60
    @State private var iCloudSyncInput = false
    @State private var showNotificationsDenied = false
    @State private var showiCloudSyncUnavailable = false
    @State private var showEraseConfirm = false
    @State private var showEraseFinal = false
    @State private var showEraseFailed = false
    @State private var isErasing = false
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
        !contactsInput.isEmpty
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
                    TrustedContactsList(contacts: $contactsInput, state: $contactsEditor, accent: appTheme.accent)
                } header: {
                    Text("Trusted Contacts")
                } footer: {
                    Text("contacts.footer")
                        .sectionFooterSpacing()
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
                        .sectionFooterSpacing()
                }

                Section {
                    // Two steps before anything goes: a wrong tap here can't
                    // be undone, and deleting the app alone doesn't remove
                    // the iCloud copy.
                    Button(role: .destructive) { showEraseConfirm = true } label: {
                        oneLineButtonLabel("Erase All Data", systemImage: "trash")
                    }
                    // A red button, but the secondary style: the screen's
                    // prominent action is Save, not a destructive one.
                    .secondaryActionStyle(accent: .red)
                    .disabled(isErasing)
                    .alert("Erase all your data?", isPresented: $showEraseConfirm) {
                        Button("erase.continue", role: .destructive) { showEraseFinal = true }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("erase.message")
                    }
                    .alert("This can't be undone", isPresented: $showEraseFinal) {
                        Button("Erase Everything", role: .destructive, action: eraseEverything)
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("erase.final")
                    }
                    .alert("Couldn't Reach iCloud", isPresented: $showEraseFailed) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text("erase.failed")
                    }
                } header: {
                    Text("Your Data")
                } footer: {
                    Text("erase.footer")
                        .sectionFooterSpacing()
                }
            }
            .scrollContentBackground(.hidden)
            .background(appTheme.background)
            .overlay {
                if isErasing {
                    ProgressView("Erasing…")
                        .font(.title3)
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .background { VerticalBarsReader(isVertical: $barsVertical) }
            // On the right page of a folded iPhone Duo the system gives this
            // sheet a side bar whose first item sits under the status bar
            // (iOS 27.1); kept horizontal, the bar starts below it.
            .horizontalToolbars(keepSheetToolbarHorizontal)
            .toolbar {
                if barsVertical && !keepSheetToolbarHorizontal {
                    // iPhone Duo side bar: plain leading/trailing icon items,
                    // which the system lays out below the status bar (the
                    // prominent confirm slot goes underneath it).
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel", systemImage: "xmark", role: .cancel, action: cancel)
                            .toolbarNavigationStyle(accent: appTheme.accent)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save", systemImage: "checkmark", action: save)
                            .toolbarNavigationStyle(accent: appTheme.accent)
                            .disabled(!canSave)
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel, action: cancel) {
                            toolbarButtonLabel("Cancel", icon: "xmark", iconsOnly: false, iconWithWords: false)
                                .padding(.horizontal, 2)
                                .fixedSize()
                        }
                        .toolbarSecondaryStyle(accent: appTheme.accent)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: save) {
                            toolbarButtonLabel("Save", icon: "checkmark", iconsOnly: false, iconWithWords: false)
                                .foregroundStyle(canSave ? appTheme.onAccent : Color.secondary)
                                .padding(.horizontal, 2)
                        }
                        .primaryActionStyle(accent: appTheme.accent)
                        .disabled(!canSave)
                    }
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
            .trustedContactsEditing($contactsInput, state: $contactsEditor, appTheme: appTheme)
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
                    .overlay {
                        Circle().stroke(selected ? appTheme.accent : Color.secondary.opacity(0.3), lineWidth: selected ? 3 : 1)
                    }
                    .overlay {
                        if selected {
                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(appTheme.accent).accessibilityHidden(true)
                        }
                    }
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

    private func eraseEverything() {
        isErasing = true
        Task {
            let erased = await DataEraser.eraseEverything(store: store, appTheme: appTheme)
            isErasing = false
            if erased {
                // Home falls back to onboarding once the name is gone.
                dismiss()
            } else {
                showEraseFailed = true
            }
        }
    }

    /// Discards the session, including a theme previewed live.
    private func cancel() {
        appTheme.theme = originalTheme
        dismiss()
    }

    private func save() {
        userName = userNameInput.trimmingCharacters(in: .whitespaces)
        let stored = TrustedContacts.split(contactsInput)
        contactName = stored.name
        contactEmail = stored.email
        additionalContactsJSON = stored.additionalJSON

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

private extension View {
    /// A footer note otherwise runs straight into the next section's header,
    /// while sections without one get the full gap; this evens them out.
    func sectionFooterSpacing() -> some View {
        padding(.bottom, 20)
    }
}
