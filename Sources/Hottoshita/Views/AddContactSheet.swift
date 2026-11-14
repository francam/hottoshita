import PhotosUI
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
    /// Kept from the contact being edited, or from Contacts when picked.
    @State private var photo: Data?
    /// The photo library pick in progress (Apple's picker: no permission
    /// needed, the app only receives the one photo chosen).
    @State private var photoItem: PhotosPickerItem?

    init(editing: TrustedContact? = nil, onAdd: @escaping (TrustedContact) -> Void) {
        self.editing = editing
        self.onAdd = onAdd
        _name = State(initialValue: editing?.name ?? "")
        _email = State(initialValue: editing?.email ?? "")
        _photo = State(initialValue: editing?.photo)
    }
    @State private var showContactPicker = false

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Their picture: from Contacts when picked there, or any
                    // photo from the library — so a typed-in contact needn't
                    // stay initials.
                    VStack(spacing: 10) {
                        ContactAvatar(contact: TrustedContact(name: name, email: email, photo: photo),
                                      accent: appTheme.accent, size: 96)
                        HStack(spacing: 20) {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Text(photo == nil ? LocalizedStringKey("Add Photo") : "Change Photo")
                                    .font(.title3.weight(.semibold))
                            }
                            if photo != nil {
                                Button("Remove Photo", role: .destructive) { photo = nil }
                                    .font(.title3)
                            }
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(appTheme.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .onChange(of: photoItem) { item in
                        Task {
                            guard let data = try? await item?.loadTransferable(type: Data.self),
                                  let image = UIImage(data: data) else { return }
                            photo = ContactPhoto.squared(image)
                        }
                    }
                }

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
                                             email: email.trimmingCharacters(in: .whitespaces),
                                             photo: photo))
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
                ContactPickerPresenter(isPresented: $showContactPicker) { pickedName, pickedEmail, pickedPhoto in
                    name = pickedName
                    email = pickedEmail
                    photo = pickedPhoto
                }
            }
        }
        .background(appTheme.background.ignoresSafeArea())
    }
}
