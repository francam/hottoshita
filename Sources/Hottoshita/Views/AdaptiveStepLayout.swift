import SwiftUI

extension EnvironmentValues {
    /// Compact vertical size class (iPhone landscape): screens lay content
    /// out side-by-side and shrink decoration so they fit without scrolling.
    var isCompactHeight: Bool { verticalSizeClass == .compact }

    /// Regular height but too short for the roomy layout — iPhone SE
    /// (667pt). Screens keep their portrait structure and only tighten
    /// spacing/decoration, so every check-in answer fits without scrolling.
    var isShortHeight: Bool {
        get { self[ShortHeightKey.self] }
        set { self[ShortHeightKey.self] = newValue }
    }

    /// Either constraint calls for the tighter spacing.
    var isDense: Bool { isCompactHeight || isShortHeight }
}

private struct ShortHeightKey: EnvironmentKey {
    static let defaultValue = false
}

extension View {
    /// Measures the presentation root and publishes `isShortHeight`. Like
    /// the Dynamic Type cap, apply at every sheet/cover root — presented
    /// views don't inherit it.
    func detectsShortHeight() -> some View {
        modifier(ShortHeightReader())
    }
}

private struct ShortHeightReader: ViewModifier {
    /// Safe-area height: SE ≈ 647pt; the shortest notched iPhone (mini)
    /// ≈ 728pt, which already fits the roomy layout.
    private static let threshold: CGFloat = 700
    @State private var isShort = false

    func body(content: Content) -> some View {
        content
            .environment(\.isShortHeight, isShort)
            .onGeometryChange(for: Bool.self) { $0.size.height < Self.threshold } action: { isShort = $0 }
    }
}

/// Two-slot layout for survey/onboarding steps: header (icon + question)
/// stacked above the controls in portrait, beside them in compact height.
struct AdaptiveStepLayout<Header: View, Controls: View>: View {
    @Environment(\.isCompactHeight) private var isCompactHeight
    @Environment(\.isShortHeight) private var isShortHeight
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
            : AnyLayout(VStackLayout(spacing: isShortHeight ? min(spacing, 24) : spacing))

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
    @Environment(\.isDense) private var isDense
    @EnvironmentObject private var appTheme: AppTheme
    let icon: String
    let question: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var iconSize: CGFloat = 64
    /// Hidden while the keyboard is up so the step fits above it.
    var showIcon: Bool = true

    var body: some View {
        VStack(spacing: isDense ? 10 : 16) {
            if showIcon {
                Image(systemName: icon)
                    .font(.system(size: isDense ? 40 : iconSize))
                    .foregroundStyle(appTheme.accent)
                    .accessibilityHidden(true)
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
