import SwiftUI

/// Adds a trusted contact by typing (or picking from Contacts), or edits one
/// already in the list. The contact is only handed back on Add/Save; the
/// screen that owns the list still stages it until its own Save.
struct AddContactSheet: View {
    /// Set when editing: prefilled, and handed back with the same id.
    var editing: TrustedContact?
    let onAdd: (TrustedContact) -> Void
    @EnvironmentObject private var appTheme: AppTheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.keepSheetToolbarHorizontal) private var keepSheetToolbarHorizontal
    @State private var name: String
    @State private var email: String

    init(editing: TrustedContact? = nil, onAdd: @escaping (TrustedContact) -> Void) {
        self.editing = editing
        self.onAdd = onAdd
        _name = State(initialValue: editing?.name ?? "")
        _email = State(initialValue: editing?.email ?? "")
    }
    @State private var showContactPicker = false

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name").font(.caption).foregroundStyle(.secondary)
                        TextField("Contact name", text: $name)
                            .font(.title3)
                            .accessibilityIdentifier("addContact.name")
                    }
                    .padding(.vertical, 4)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email").font(.caption).foregroundStyle(.secondary)
                        TextField("Contact email", text: $email)
                            .font(.title3)
                            .accessibilityIdentifier("addContact.email")
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.vertical, 4)
                    Button {
                        showContactPicker = true
                    } label: {
                        Label("Choose from Contacts", systemImage: "person.crop.circle.badge.plus")
                            .font(.title3)
                    }
                    .foregroundStyle(appTheme.accent)
                }
            }
            .scrollContentBackground(.hidden)
            .background(appTheme.background)
            .navigationTitle(editing == nil ? "Add Contact" : "Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            // On a folded iPhone Duo's right page, keep Cancel/Add in a
            // horizontal bar below the status bar (see History).
            .horizontalToolbars(keepSheetToolbarHorizontal)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: {
                        Text("Cancel").font(.title3.weight(.semibold))
                    }
                    .toolbarSecondaryStyle(accent: appTheme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onAdd(TrustedContact(id: editing?.id ?? UUID(),
                                             name: name.trimmingCharacters(in: .whitespaces),
                                             email: email.trimmingCharacters(in: .whitespaces)))
                        dismiss()
                    } label: {
                        Text(editing == nil ? "Add" : "Save")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(canAdd ? appTheme.onAccent : Color.secondary)
                    }
                    .primaryActionStyle(accent: appTheme.accent)
                    .disabled(!canAdd)
                }
            }
            .background {
                ContactPickerPresenter(isPresented: $showContactPicker) { pickedName, pickedEmail in
                    name = pickedName
                    email = pickedEmail
                }
            }
        }
        .background(appTheme.background.ignoresSafeArea())
    }
}
