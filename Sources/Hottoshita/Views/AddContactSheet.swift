import SwiftUI

/// Adds a trusted contact by typing (or picking from Contacts), or edits one
/// already in the list. The contact is only handed back on Add/Save;
/// Settings still stages it until its own Save.
struct AddContactSheet: View {
    /// Set when editing: prefilled, and handed back with the same id.
    var editing: TrustedContact?
    let onAdd: (TrustedContact) -> Void
    @EnvironmentObject private var appTheme: AppTheme
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var email: String
    @State private var showContactPicker = false

    init(editing: TrustedContact? = nil, onAdd: @escaping (TrustedContact) -> Void) {
        self.editing = editing
        self.onAdd = onAdd
        _name = State(initialValue: editing?.name ?? "")
        _email = State(initialValue: editing?.email ?? "")
    }

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
                    Button {
                        onAdd(TrustedContact(id: editing?.id ?? UUID(),
                                             name: name.trimmingCharacters(in: .whitespaces),
                                             email: email.trimmingCharacters(in: .whitespaces)))
                        dismiss()
                    } label: {
                        Text(editing == nil ? "Add" : "Save")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(canAdd ? appTheme.onAccent : Color.secondary)
                            .padding(.horizontal, 2)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appTheme.accent)
                    .disabled(!canAdd)
                }
            }
            .background(
                ContactPickerPresenter(isPresented: $showContactPicker) { pickedName, pickedEmail in
                    name = pickedName
                    email = pickedEmail
                }
            )
        }
        .background(appTheme.background.ignoresSafeArea())
    }
}
