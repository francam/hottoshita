import SwiftUI

/// What the trusted-contacts list asks its screen to present. The picker and
/// sheets hang off the screen (`trustedContactsEditing`), not the rows: from
/// inside a lazy list or scroll view they don't present reliably. (The Add
/// choice dialog stays on its button, which it points at.)
struct ContactsEditorState {
    var showAddChoice = false
    var showPicker = false
    var showAddSheet = false
    var editing: TrustedContact?
}

/// The people who receive the report — the same list in onboarding and in
/// Settings. Every contact is the same kind of row (tap to edit, remove
/// button); one Add button asks how to add someone — from Contacts or typed
/// in. Drop it into a Form section, or set `cards` to stand alone.
struct TrustedContactsList: View {
    @Binding var contacts: [TrustedContact]
    @Binding var state: ContactsEditorState
    let accent: Color
    var cards = false

    var body: some View {
        ForEach(contacts) { contact in
            HStack(spacing: 12) {
                Button { state.editing = contact } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name).font(.title3)
                        Text(contact.email).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Double-tap to edit."))

                // An explicit button rather than swipe-to-delete, which
                // elderly users rarely discover.
                Button(role: .destructive) {
                    contacts.removeAll { $0.id == contact.id }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Remove \(contact.name)"))
            }
            .padding(cards ? 14 : 0)
            .background(cards ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: 14))
        }

        if contacts.count < TrustedContacts.maximum {
            Button { state.showAddChoice = true } label: {
                oneLineButtonLabel("Add Contact", systemImage: "plus")
            }
            .secondaryActionStyle(accent: accent)
            // On the button, so it points at it (iOS 26+ shows it as a
            // popover anchored to whatever it's attached to).
            .confirmationDialog(Text("Add Contact"), isPresented: $state.showAddChoice, titleVisibility: .visible) {
                Button("Choose from Contacts") { state.showPicker = true }
                Button("Type a Contact") { state.showAddSheet = true }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

extension View {
    /// Presents the contacts list's picker and add/edit sheets from this
    /// screen. A contact already in the list (same email) isn't added twice.
    /// `fold`: the screen's hinge, so the add/edit sheet is placed like
    /// History/Settings (right page folded, centred flat).
    func trustedContactsEditing(_ contacts: Binding<[TrustedContact]>,
                                state: Binding<ContactsEditorState>,
                                appTheme: AppTheme,
                                fold: Fold? = nil) -> some View {
        func add(_ contact: TrustedContact) {
            let email = contact.email.lowercased()
            guard contacts.wrappedValue.count < TrustedContacts.maximum,
                  !contacts.wrappedValue.contains(where: { $0.email.lowercased() == email }) else { return }
            contacts.wrappedValue.append(contact)
        }
        return background {
            ContactPickerPresenter(isPresented: state.showPicker) { name, email in
                add(TrustedContact(name: name, email: email))
            }
        }
        .sheet(isPresented: state.showAddSheet) {
            AddContactSheet(onAdd: add)
                .environmentObject(appTheme)
                .cappedDynamicType()
                .placedOffFold(fold)
        }
        .sheet(item: state.editing) { contact in
            AddContactSheet(editing: contact) { updated in
                if let i = contacts.wrappedValue.firstIndex(where: { $0.id == updated.id }) {
                    contacts.wrappedValue[i] = updated
                }
            }
            .environmentObject(appTheme)
            .cappedDynamicType()
            .placedOffFold(fold)
        }
    }
}

/// A full-width button label: icon and words on one line where they fit;
/// in a narrow column (iPhone Duo closed, held sideways) just the words,
/// rather than wrapping onto two lines.
func oneLineButtonLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
    ViewThatFits(in: .horizontal) {
        Label(title, systemImage: systemImage)
        Text(title).minimumScaleFactor(0.8)
    }
    .lineLimit(1)
    .font(.title3.weight(.semibold))
    .frame(maxWidth: .infinity)
    .padding(.vertical, 6)
}
