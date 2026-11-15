import SwiftUI

// The app's button and tile styles, in one place.
//
// Flat pastel inside screens (decided 2026-11-15), the same on every iOS
// version: tinted capsules and filled primary buttons, as in 1.0.1, and as an
// Android version would draw them with Material 3. Liquid Glass is left to
// the system: bars, sheets, alerts and the toolbar buttons (Back, Cancel,
// Save, Done), which have to stay toolbar items so the iPhone Duo can move
// them into its side bar. The deployment target stays at iOS 16, so the
// toolbar styles still branch on iOS 26.

extension View {
    /// The screen's one primary action: a filled capsule in the theme colour.
    func primaryActionStyle(accent: Color) -> some View {
        buttonStyle(.borderedProminent).tint(accent)
    }

    /// Secondary actions: a capsule lightly tinted with the theme colour. The
    /// label is a deeper tone of it in light mode and a brighter one in dark
    /// mode, so it stays easy to read on the tint (≥ 4.5:1 in every theme;
    /// the plain accent measured 3.8–4.0:1 in light mode and was dim in dark).
    func secondaryActionStyle(accent: Color) -> some View {
        buttonStyle(.bordered)
            .tint(accent)
            // On the whole label, icon included: the bordered style alone
            // left some icons (Add Contact's "+") in the system blue.
            .foregroundStyle(accent.readableOnTint)
    }

    /// A toolbar button that isn't the confirming action (e.g. Cancel).
    /// Toolbar items are already glass on 26+, so no button style there —
    /// just the theme colour on the label. Before 26, the filled pill the
    /// app has always used (its label defaults to white).
    @ViewBuilder
    func toolbarSecondaryStyle(accent: Color) -> some View {
        if #available(iOS 26.0, *) {
            foregroundStyle(accent.readableOnDark)
        } else {
            buttonStyle(.borderedProminent).tint(accent)
        }
    }

    /// Navigation toolbar buttons (Back / Cancel in the check-in flow):
    /// plain system glass items on 26+, the light bordered pill before it.
    @ViewBuilder
    func toolbarNavigationStyle(accent: Color) -> some View {
        if #available(iOS 26.0, *) {
            foregroundStyle(accent.readableOnDark)
        } else {
            buttonStyle(.bordered).tint(accent).foregroundStyle(accent.readableOnTint)
        }
    }

    /// Background for a tappable answer tile: filled with the accent when
    /// selected, a soft grey otherwise, as in 1.0.1 — no outline. With
    /// Increase Contrast on, unselected tiles get an accent outline, since
    /// the grey alone is a faint edge (about 1.1:1 against the background).
    func answerTileBackground(selected: Bool, accent: Color, cornerRadius: CGFloat) -> some View {
        modifier(AnswerTileBackground(selected: selected, accent: accent, cornerRadius: cornerRadius))
    }
}

private struct AnswerTileBackground: ViewModifier {
    let selected: Bool
    let accent: Color
    let cornerRadius: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        content
            .background(selected ? accent : Color(.systemGroupedBackground), in: shape)
            .overlay {
                if !selected && contrast == .increased {
                    shape.strokeBorder(accent, lineWidth: 2)
                }
            }
    }
}

extension Color {
    /// This colour as text on the toolbar's glass: unchanged in light mode,
    /// 35% brighter in dark mode, where the theme colour read dim (Back,
    /// Cancel).
    var readableOnDark: Color {
        let base = UIColor(self)
        return Color(uiColor: UIColor { traits in
            let resolved = base.resolvedColor(with: traits)
            return traits.userInterfaceStyle == .dark ? resolved.mixed(with: .white, amount: 0.35) : resolved
        })
    }

    /// This colour as text on a light tint of itself (secondary buttons):
    /// 20% deeper in light mode, 35% brighter in dark mode.
    var readableOnTint: Color {
        let base = UIColor(self)
        return Color(uiColor: UIColor { traits in
            let resolved = base.resolvedColor(with: traits)
            return traits.userInterfaceStyle == .dark
                ? resolved.mixed(with: .white, amount: 0.35)
                : resolved.mixed(with: .black, amount: 0.20)
        })
    }
}

extension View {
    /// An opaque sheet background (iOS 16.4+), for sheets whose content
    /// must stay easy to read rather than show the screen behind it.
    @ViewBuilder
    func solidPresentationBackground(_ color: Color) -> some View {
        if #available(iOS 16.4, *) {
            presentationBackground(color)
        } else {
            self
        }
    }
}
