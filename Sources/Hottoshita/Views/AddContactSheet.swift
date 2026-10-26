import SwiftUI

/// Adds one more trusted contact from Settings — typed in, or picked from
/// Contacts. The contact is only handed back on Add; Settings still stages it
/// until its own Save.
struct AddContactSheet: View {
    let onAdd: (TrustedContact) -> Void
    @EnvironmentObject private var appTheme: AppTheme
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
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
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: {
                        Text("Cancel").font(.title3.weight(.semibold))
                    }
                    .toolbarSecondaryStyle(accent: appTheme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onAdd(TrustedContact(name: name.trimmingCharacters(in: .whitespaces),
                                             email: email.trimmingCharacters(in: .whitespaces)))
                        dismiss()
                    } label: {
                        Text("Add")
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
