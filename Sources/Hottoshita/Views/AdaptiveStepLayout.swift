import SwiftUI

extension EnvironmentValues {
    /// Compact vertical size class (iPhone landscape): screens lay content
    /// out side-by-side and shrink decoration so they fit without scrolling.
    var isCompactHeight: Bool { verticalSizeClass == .compact }
}

/// Two-slot layout for survey/onboarding steps: header (icon + question)
/// stacked above the controls in portrait, beside them in compact height.
struct AdaptiveStepLayout<Header: View, Controls: View>: View {
    @Environment(\.isCompactHeight) private var isCompactHeight
    var spacing: CGFloat = 40
    /// Side-by-side even at regular height — used on iPad when the keyboard
    /// eats too much height for the stacked layout.
    var forceSideBySide = false
    @ViewBuilder let header: () -> Header
    @ViewBuilder let controls: () -> Controls

    var body: some View {
        if isCompactHeight || forceSideBySide {
            HStack(spacing: 24) {
                header()
                    .frame(maxWidth: .infinity)
                controls()
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: spacing) {
                header()
                controls()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Icon + question (+ optional subtitle) header shared by all steps.
struct StepHeader: View {
    @Environment(\.isCompactHeight) private var isCompactHeight
    @EnvironmentObject private var appTheme: AppTheme
    let icon: String
    let question: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var iconSize: CGFloat = 64
    /// Hidden while the keyboard is up so the step fits above it.
    var showIcon: Bool = true

    var body: some View {
        VStack(spacing: isCompactHeight ? 10 : 16) {
            if showIcon {
                Image(systemName: icon)
                    .font(.system(size: isCompactHeight ? 40 : iconSize))
                    .foregroundStyle(appTheme.accent)
            }
            Text(question)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
            if let subtitle {
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
    }
}
