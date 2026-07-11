import SwiftUI

enum ColorTheme: String, CaseIterable {
    case `default`, pink, lavender, mint, sky, peach, lemon

    var color: Color {
        switch self {
        case .default:  return Color(.systemBackground)
        case .pink:     return Color(red: 1.00, green: 0.88, blue: 0.90)
        case .lavender: return Color(red: 0.91, green: 0.88, blue: 1.00)
        case .mint:     return Color(red: 0.85, green: 0.96, blue: 0.90)
        case .sky:      return Color(red: 0.85, green: 0.93, blue: 1.00)
        case .peach:    return Color(red: 1.00, green: 0.90, blue: 0.82)
        case .lemon:    return Color(red: 1.00, green: 0.97, blue: 0.82)
        }
    }

    var accentColor: Color {
        switch self {
        case .default:  return .teal
        case .pink:     return Color(red: 0.76, green: 0.25, blue: 0.42)
        case .lavender: return Color(red: 0.48, green: 0.30, blue: 0.75)
        case .mint:     return Color(red: 0.18, green: 0.60, blue: 0.40)
        case .sky:      return Color(red: 0.18, green: 0.45, blue: 0.78)
        case .peach:    return Color(red: 0.78, green: 0.38, blue: 0.18)
        case .lemon:    return Color(red: 0.70, green: 0.52, blue: 0.08)
        }
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

    var background: Color { theme.color }
    var accent: Color { theme.accentColor }
}
