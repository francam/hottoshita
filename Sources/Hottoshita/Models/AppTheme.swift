import SwiftUI
import UIKit

enum ColorTheme: String, CaseIterable {
    case `default`, pink, lavender, mint, sky, peach, lemon

    /// The pastel used for the settings swatch and the dark-mode tint.
    private var pastel: UIColor? {
        switch self {
        case .default:  return nil
        case .pink:     return UIColor(red: 1.00, green: 0.88, blue: 0.90, alpha: 1)
        case .lavender: return UIColor(red: 0.91, green: 0.88, blue: 1.00, alpha: 1)
        case .mint:     return UIColor(red: 0.85, green: 0.96, blue: 0.90, alpha: 1)
        case .sky:      return UIColor(red: 0.85, green: 0.93, blue: 1.00, alpha: 1)
        case .peach:    return UIColor(red: 1.00, green: 0.90, blue: 0.82, alpha: 1)
        case .lemon:    return UIColor(red: 1.00, green: 0.97, blue: 0.82, alpha: 1)
        }
    }

    /// Accent used in light mode: dark enough for white button text (≥ 4.5:1).
    private var lightAccent: UIColor {
        switch self {
        // Deep teal, not .systemTeal — white button text needs ≥ 4.5:1.
        case .default:  return UIColor(red: 0.00, green: 0.50, blue: 0.58, alpha: 1)
        case .pink:     return UIColor(red: 0.76, green: 0.25, blue: 0.42, alpha: 1)
        case .lavender: return UIColor(red: 0.48, green: 0.30, blue: 0.75, alpha: 1)
        case .mint:     return UIColor(red: 0.10, green: 0.50, blue: 0.32, alpha: 1)
        case .sky:      return UIColor(red: 0.18, green: 0.45, blue: 0.78, alpha: 1)
        case .peach:    return UIColor(red: 0.65, green: 0.30, blue: 0.12, alpha: 1)
        case .lemon:    return UIColor(red: 0.58, green: 0.42, blue: 0.03, alpha: 1)
        }
    }

    /// Accent used in dark mode: as bright a tone of the theme colour as still
    /// keeps white button text readable (≥ 4.5:1).
    private var darkAccent: UIColor {
        switch self {
        case .default:  return UIColor(red: 0.00, green: 0.50, blue: 0.58, alpha: 1)
        case .pink:     return UIColor(red: 0.78, green: 0.28, blue: 0.44, alpha: 1)
        case .lavender: return UIColor(red: 0.54, green: 0.37, blue: 0.80, alpha: 1)
        case .mint:     return UIColor(red: 0.12, green: 0.52, blue: 0.34, alpha: 1)
        case .sky:      return UIColor(red: 0.19, green: 0.46, blue: 0.79, alpha: 1)
        case .peach:    return UIColor(red: 0.71, green: 0.36, blue: 0.18, alpha: 1)
        case .lemon:    return UIColor(red: 0.59, green: 0.43, blue: 0.04, alpha: 1)
        }
    }

    /// Swatch colour shown in the theme pickers (always the pastel).
    var color: Color {
        guard let pastel else { return Color(.systemBackground) }
        return Color(uiColor: pastel)
    }

    /// Screen background under the theme gradient (ThemeBackdrop): white in
    /// light mode for every theme — the colour comes from the gradient, which
    /// fades from the theme colour at the top into this — and near-black
    /// tinted with the theme hue in dark mode.
    var background: Color {
        guard let pastel else { return Color(.systemBackground) }
        let dark = pastel.mixed(with: .black, amount: 0.85)
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : .systemBackground })
    }

    /// Behind grouped lists (Settings): the system's grouped grey in light
    /// mode, so the white section cards stand out; the tinted near-black in
    /// dark mode.
    var groupedBackground: Color {
        guard let pastel else { return Color(.systemGroupedBackground) }
        let dark = pastel.mixed(with: .black, amount: 0.85)
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : .systemGroupedBackground })
    }

    var accentColor: Color {
        Color(uiColor: UIColor { [light = lightAccent, dark = darkAccent] in
            $0.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// Text/icon colour for accent-filled buttons: always white — the accents
    /// in both modes are kept dark enough for it (≥ 4.5:1).
    var onAccentColor: Color {
        .white
    }

    var label: LocalizedStringKey {
        switch self {
        case .default:  return "Default"
        case .pink:     return "Pink"
        case .lavender: return "Lavender"
        case .mint:     return "Mint"
        case .sky:      return "Sky"
        case .peach:    return "Peach"
        case .lemon:    return "Lemon"
        }
    }
}

final class AppTheme: ObservableObject {
    @AppStorage("colorTheme") var theme: ColorTheme = .default

    var background: Color { theme.background }
    var groupedBackground: Color { theme.groupedBackground }
    var accent: Color { theme.accentColor }
    var onAccent: Color { theme.onAccentColor }

    /// Points the home-screen icon at the current theme's colours.
    /// iOS shows a system alert whenever the icon changes, so this is only
    /// called when a choice is committed (onboarding finishes / the settings
    /// sheet closes), never while the user is still browsing swatches.
    func updateAppIcon() {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let name = theme == .default ? nil : "icon-\(theme.rawValue)"
        guard UIApplication.shared.alternateIconName != name else { return }
        UIApplication.shared.setAlternateIconName(name)
    }
}

extension UIColor {
    /// Linear blend towards `other` in RGB space; `amount` 0 = self, 1 = other.
    func mixed(with other: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * amount,
            green: g1 + (g2 - g1) * amount,
            blue: b1 + (b2 - b1) * amount,
            alpha: a1 + (a2 - a1) * amount
        )
    }
}

/// The background of the main screens (onboarding, Home, check-in, summary):
/// the theme colour fades down from the top into white (light mode) or the
/// tinted near-black (dark mode), as on the Watch and in the emailed report. It's gone
/// by mid-screen, so buttons and tiles sit on the plain background. Lists in
/// sheets (Settings, History) keep `groupedBackground`.
struct ThemeBackdrop: View {
    @EnvironmentObject private var appTheme: AppTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        appTheme.background
            .overlay {
                // Stronger in dark mode, where the same tint barely shows.
                LinearGradient(colors: [appTheme.accent.opacity(colorScheme == .dark ? 0.45 : 0.30), .clear],
                               startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.6))
            }
            .ignoresSafeArea()
    }
}
