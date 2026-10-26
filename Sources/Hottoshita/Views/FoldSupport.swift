import SwiftUI

// iPhone Duo's inner display has a vertical hinge when held in landscape.
// Half-open like a book, content that crosses it is hard to read and tap,
// so screens that would centre content on the crease use a two-page layout
// instead — one part on each side, nothing on the fold — open flat as well
// as folded, so folding doesn't rearrange the screen (HIG: "Designing for
// iPhone Duo"). Other devices, and the Duo closed, never report a hinge.

/// The x-range the vertical hinge occupies (folded or flat), in the
/// measuring view's own coordinates.
struct VerticalFold: Equatable {
    var minX: CGFloat
    var maxX: CGFloat
    /// Actually bent (book pose) rather than lying flat.
    var isActive: Bool
}

extension EnvironmentValues {
    /// True inside a two-page fold layout, so children can size for half
    /// the display (e.g. the feelings grid drops to two columns).
    var isFoldSplit: Bool {
        get { self[FoldSplitKey.self] }
        set { self[FoldSplitKey.self] = newValue }
    }
}

private struct FoldSplitKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Set by the presenter when it has put a sheet where the system would
    /// show its toolbar vertically (iPhone Duo, trailing placement). That
    /// side bar's first item lands under the status bar (iOS 27.1), so the
    /// sheet keeps its toolbar horizontal (horizontalToolbars) instead.
    var keepSheetToolbarHorizontal: Bool {
        get { self[KeepSheetToolbarHorizontalKey.self] }
        set { self[KeepSheetToolbarHorizontalKey.self] = newValue }
    }
}

private struct KeepSheetToolbarHorizontalKey: EnvironmentKey {
    static let defaultValue = false
}

/// Reads `isFoldSplit` where it's set — inside a fold layout's children. A
/// step view's own @Environment sees the value from outside its
/// AdaptiveStepLayout, so it would never be true there.
struct FoldSplitReader<Content: View>: View {
    @Environment(\.isFoldSplit) private var isFoldSplit
    @ViewBuilder let content: (Bool) -> Content

    var body: some View { content(isFoldSplit) }
}

private struct VerticalFoldKey: PreferenceKey {
    static let defaultValue: VerticalFold? = nil
    static func reduce(value: inout VerticalFold?, nextValue: () -> VerticalFold?) {
        value = value ?? nextValue()
    }
}

extension View {
    /// Reports a vertical hinge crossing this view (nil otherwise).
    /// The reserved-region API is iOS 27.1+; earlier systems never fold.
    func readsVerticalFold(_ fold: Binding<VerticalFold?>) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: VerticalFoldKey.self, value: verticalFold(in: proxy))
            }
        }
        .onPreferenceChange(VerticalFoldKey.self) { fold.wrappedValue = $0 }
    }
}

private func verticalFold(in proxy: GeometryProxy) -> VerticalFold? {
    guard #available(iOS 27.1, *) else { return nil }
    // Inactive regions too: the hinge is reported while the Duo lies flat,
    // so the two-page layout is already in place before it folds and
    // bending it changes nothing (HIG: avoid extreme layout changes when
    // folding). iPhone Duo has one fold. Taller than wide = runs top to
    // bottom (landscape / book pose); a horizontal fold (portrait) already
    // falls between our stacked header and controls.
    guard let region = proxy.reservedRegions(kind: .division, options: .includeInactive).first,
          region.frame.height > region.frame.width else { return nil }
    return VerticalFold(minX: region.frame.minX, maxX: region.frame.maxX, isActive: region.isActive)
}

/// Places its first subview on the page left of the fold and its second on
/// the page right of it, each centred vertically, nothing on the crease.
/// A Layout (not an HStack branch) so it can swap in through AnyLayout
/// without rebuilding the children — see AdaptiveStepLayout.
struct FoldSplitLayout: Layout {
    var fold: VerticalFold

    private func pages(in width: CGFloat) -> (left: CGFloat, right: CGFloat) {
        (max(fold.minX, 0), max(width - fold.maxX, 0))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? fold.maxX * 2
        let (left, right) = pages(in: width)
        let heights = zip(subviews, [left, right]).map { subview, pageWidth in
            subview.sizeThatFits(ProposedViewSize(width: pageWidth, height: proposal.height)).height
        }
        return CGSize(width: width, height: proposal.height ?? heights.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (left, right) = pages(in: bounds.width)
        let origins = [bounds.minX, bounds.minX + fold.maxX]
        for (index, subview) in subviews.prefix(2).enumerated() {
            let pageWidth = index == 0 ? left : right
            let size = subview.sizeThatFits(ProposedViewSize(width: pageWidth, height: bounds.height))
            subview.place(
                at: CGPoint(x: origins[index] + pageWidth / 2, y: bounds.midY),
                anchor: .center,
                proposal: ProposedViewSize(width: pageWidth, height: size.height)
            )
        }
    }
}

/// Reports whether the system is showing toolbars vertically (iPhone Duo
/// side bar). Place in the background of a NavigationStack's content;
/// always false before iOS 27.1.
struct VerticalBarsReader: View {
    @Binding var isVertical: Bool

    var body: some View {
        if #available(iOS 27.1, *) {
            EdgeReader(isVertical: $isVertical)
        } else {
            Color.clear
        }
    }

    @available(iOS 27.1, *)
    private struct EdgeReader: View {
        @Environment(\.toolbarVerticalEdge) private var edge
        @Binding var isVertical: Bool

        var body: some View {
            Color.clear
                .onChange(of: edge != nil, initial: true) { _, vertical in isVertical = vertical }
        }
    }
}

extension View {
    /// iPhone Duo inner display: half-open like a book, keep the sheet on
    /// the right page instead of across the crease (that's where Home's
    /// History/Settings buttons are); lying flat, leave it centred. The
    /// system would give a trailing sheet a vertical toolbar; the sheet
    /// keeps it horizontal instead (see keepSheetToolbarHorizontal). Elsewhere:
    /// system placement.
    @ViewBuilder
    func placedOffFold(_ fold: VerticalFold?) -> some View {
        if #available(iOS 27.0, *) {
            presentationPlacement(fold?.isActive == true ? .trailing : .automatic)
                .environment(\.keepSheetToolbarHorizontal, fold?.isActive == true)
        } else {
            self
        }
    }
}

/// A toolbar button's label. In vertical bars (iPhone Duo side bar) a plain
/// Label — icon items are the only kind the system places there. In
/// horizontal bars a custom view, so the words show: the system would
/// otherwise render a Label as its icon alone, and words are clearer for
/// elderly users. A function rather than a View type, so the toolbar still
/// sees the Label itself.
@ViewBuilder
func toolbarButtonLabel(_ title: LocalizedStringKey, icon: String, iconsOnly: Bool,
                        iconWithWords: Bool = true) -> some View {
    if iconsOnly {
        Label(title, systemImage: icon)
    } else {
        HStack(spacing: 6) {
            if iconWithWords {
                Image(systemName: icon).accessibilityHidden(true)
            }
            Text(title).lineLimit(1).minimumScaleFactor(0.6)
        }
        .font(.title3.weight(.semibold))
    }
}

extension View {
    /// Keeps this view's toolbars horizontal on iPhone Duo (iOS 27.1+).
    @ViewBuilder
    func horizontalToolbars(_ on: Bool) -> some View {
        if #available(iOS 27.1, *), on {
            toolbarVerticalBehavior(.disabled)
        } else {
            self
        }
    }
}
