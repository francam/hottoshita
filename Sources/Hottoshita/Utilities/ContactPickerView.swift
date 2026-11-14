import SwiftUI
import ContactsUI

/// Presents CNContactPickerViewController from an invisible UIKit host.
/// The picker is a remote view controller and can render blank if embedded
/// directly as SwiftUI sheet content, so it must be presented, not embedded.
/// It runs out-of-process, so it needs no Contacts permission and never
/// triggers a prompt. Attach with `.background(...)` and drive via binding.
struct ContactPickerPresenter: UIViewControllerRepresentable {
    enum Purpose {
        /// A trusted contact: needs an email address.
        case trustedContact
        /// The user's own card, to prefill their name (no email needed).
        case yourself
    }

    @Binding var isPresented: Bool
    var purpose: Purpose = .trustedContact
    /// `.yourself` passes an empty email and the name the app should
    /// address the user by (see ContactName.addressName). `photo` is a
    /// small JPEG of the contact's picture, if they have one.
    var onSelect: (_ name: String, _ email: String, _ photo: Data?) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self

        if isPresented && !context.coordinator.isPresenting {
            let picker = CNContactPickerViewController()
            picker.delegate = context.coordinator
            guard purpose == .trustedContact else {
                // Any card can be "me"; selecting it returns immediately.
                context.coordinator.isPresenting = true
                host.present(picker, animated: true)
                return
            }
            // Grey out contacts that have no email address.
            picker.predicateForEnablingContact = NSPredicate(format: "emailAddresses.@count > 0")
            // Contacts with exactly one email return immediately; contacts with
            // several drill in so the user can pick which address to use.
            picker.predicateForSelectionOfContact = NSPredicate(format: "emailAddresses.@count == 1")
            picker.predicateForSelectionOfProperty = NSPredicate(format: "key == 'emailAddresses'")
            picker.displayedPropertyKeys = [CNContactEmailAddressesKey]
            context.coordinator.isPresenting = true
            host.present(picker, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPickerPresenter
        var isPresenting = false

        init(_ parent: ContactPickerPresenter) {
            self.parent = parent
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            finish()
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            if parent.purpose == .yourself {
                let full = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
                parent.onSelect(ContactName.addressName(given: contact.givenName, family: contact.familyName,
                                                        full: full, japanese: ContactName.appIsJapanese), "", nil)
                finish()
                return
            }
            if let email = contact.emailAddresses.first?.value as String? {
                parent.onSelect(displayName(for: contact), email, ContactPhoto.thumbnail(of: contact))
            }
            finish()
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            if let email = contactProperty.value as? String {
                parent.onSelect(displayName(for: contactProperty.contact), email,
                                ContactPhoto.thumbnail(of: contactProperty.contact))
            }
            finish()
        }

        private func finish() {
            isPresenting = false
            parent.isPresented = false
        }

        private func displayName(for contact: CNContact) -> String {
            CNContactFormatter.string(from: contact, style: .fullName)
                ?? contact.givenName
        }
    }
}

/// A contact's picture, made small enough to store and sync with the
/// contact: a 160 px square JPEG (a few KB). The picker hands it over with
/// the selection, so no Contacts permission is needed.
enum ContactPhoto {
    static let side: CGFloat = 160

    static func thumbnail(of contact: CNContact) -> Data? {
        guard contact.isKeyAvailable(CNContactThumbnailImageDataKey),
              let data = contact.thumbnailImageData ?? (contact.isKeyAvailable(CNContactImageDataKey) ? contact.imageData : nil),
              let image = UIImage(data: data) else { return nil }
        return squared(image)
    }

    static func squared(_ image: UIImage) -> Data? {
        let size = CGSize(width: side, height: side)
        let scale = max(side / image.size.width, side / image.size.height)
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2,
                                  width: drawn.width, height: drawn.height))
        }
        return square.jpegData(compressionQuality: 0.7)
    }
}

/// How the app addresses the user, from their contact card: Japanese uses the
/// family name with さん (田中さん), English the given name ("Good morning,
/// Miguel!"). The greeting strings add さん / the punctuation themselves.
enum ContactName {
    static var appIsJapanese: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("ja") ?? false
    }

    static func addressName(given: String, family: String, full: String, japanese: Bool) -> String {
        let preferred = japanese ? family : given
        let fallback = japanese ? given : family
        for candidate in [preferred, fallback, full] {
            let trimmed = candidate.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return trimmed }
        }
        return ""
    }
}
