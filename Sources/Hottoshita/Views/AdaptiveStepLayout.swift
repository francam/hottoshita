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
        // A single call site for header()/controls() keeps their view
        // identity stable across the axis switch below — branching into two
        // separate HStack/VStack blocks (each calling header()/controls()
        // itself) tears down and rebuilds the controls subtree whenever
        // forceSideBySide flips, which crashes on real devices if that
        // happens to be the exact moment a TextField inside it is becoming
        // first responder (e.g. the blood-pressure step's keyboard-up
        // transition on iPad). AnyLayout swaps the container without
        // destroying the children.
        let sideBySide = isCompactHeight || forceSideBySide
        let layout: AnyLayout = sideBySide
            ? AnyLayout(HStackLayout(spacing: 24))
            : AnyLayout(VStackLayout(spacing: spacing))

        layout {
            header()
                .frame(maxWidth: sideBySide ? .infinity : nil)
            controls()
                .frame(maxWidth: sideBySide ? .infinity : nil)
        }
        .padding(.horizontal, sideBySide ? 24 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
