import Foundation

/// Someone who receives the daily report. The first contact is still stored
/// in "contactName"/"contactEmail" — onboarding and existing installs are
/// unchanged — and any others live here, as JSON under "additionalContacts".
struct TrustedContact: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var email: String
    /// A small copy of their Contacts photo (JPEG, ~160 px), when they were
    /// picked from Contacts and have one. Typed-in contacts show initials.
    var photo: Data? = nil
}

enum TrustedContacts {
    /// Contacts in total, the first one included.
    static let maximum = 5
    static let storageKey = "additionalContacts"
    /// The first contact's photo, stored beside contactName/contactEmail.
    static let primaryPhotoKey = "contactPhoto"

    static func decode(_ json: String) -> [TrustedContact] {
        guard let data = json.data(using: .utf8),
              let list = try? JSONDecoder().decode([TrustedContact].self, from: data) else { return [] }
        return Array(list.prefix(maximum - 1))
    }

    static func encode(_ list: [TrustedContact]) -> String {
        guard let data = try? JSONEncoder().encode(Array(list.prefix(maximum - 1))) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// The whole list as the screens show it: the stored first contact,
    /// then the others.
    static func list(primaryName: String, primaryEmail: String, primaryPhoto: Data? = nil,
                     additionalJSON: String) -> [TrustedContact] {
        let primary = primaryName.isEmpty && primaryEmail.isEmpty
            ? [] : [TrustedContact(name: primaryName, email: primaryEmail, photo: primaryPhoto)]
        return primary + decode(additionalJSON)
    }

    /// Back to storage: the first person in the list becomes the stored
    /// first contact (so removing them promotes the next one).
    static func split(_ list: [TrustedContact]) -> (name: String, email: String, photo: Data?, additionalJSON: String) {
        guard let first = list.first else { return ("", "", nil, "") }
        return (first.name, first.email, first.photo, encode(Array(list.dropFirst())))
    }
}

/// Who a report goes to, and how it addresses them.
struct ReportRecipients {
    let contacts: [TrustedContact]
    var names: [String] { contacts.map(\.name) }
    var emails: [String] { contacts.map(\.email) }

    init(contacts: [TrustedContact]) {
        self.contacts = contacts
    }

    init(primaryName: String, primaryEmail: String, primaryPhoto: Data? = nil, additional: [TrustedContact]) {
        contacts = [TrustedContact(name: primaryName, email: primaryEmail, photo: primaryPhoto)] + additional
    }

    /// Everyone except the people left out of this one send.
    func excluding(emails left: Set<String>) -> ReportRecipients {
        ReportRecipients(contacts: contacts.filter { !left.contains($0.email.lowercased()) })
    }

    /// "Sarah, Tom" — for the user's own screens (Summary).
    var displayNames: String {
        names.joined(separator: String(localized: "list.separator"))
    }

    /// More than one: everyone in BCC, so contacts don't see each other.
    var usesBCC: Bool { emails.count > 1 }

    /// One contact is greeted by name. With several in BCC, naming them all
    /// would reveal who else received it, so the greeting is generic.
    var greetingName: String? { names.count == 1 ? names[0] : nil }
}
