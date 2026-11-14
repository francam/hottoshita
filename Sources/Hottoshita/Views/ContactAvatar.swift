import SwiftUI

/// A trusted contact's round picture: their Contacts photo when they were
/// picked from Contacts, otherwise their initials on a soft accent circle.
struct ContactAvatar: View {
    let contact: TrustedContact
    let accent: Color
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let data = contact.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(Self.initials(of: contact.name))
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(accent.opacity(0.15))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    /// "Sarah Smith" → "SS", "Tom" → "T"; Japanese names (no spaces) → the
    /// first character, which is how a name stamp would read too.
    static func initials(of name: String) -> String {
        let words = name.split(separator: " ").filter { !$0.isEmpty }
        let letters = words.prefix(2).compactMap(\.first).map(String.init)
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }
}
