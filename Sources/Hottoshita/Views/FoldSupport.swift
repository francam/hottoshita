import SwiftUI

// iPhone Duo's inner display has a hinge: running top to bottom when the
// device is held in landscape, across when it's held upright. Half-open
// (book or laptop pose), content that crosses it is hard to read and tap, so
// screens that would centre content on the crease use a two-page layout
// instead — one part on each side, nothing on the fold — open flat as well
// as folded, so folding doesn't rearrange the screen (HIG: "Designing for
// iPhone Duo"). Other devices, and the Duo closed, never report a hinge.

/// Where the hinge is (folded or flat), in the measuring view's own
/// coordinates.
struct Fold: Equatable {
    var frame: CGRect
    /// Actually bent (book/laptop pose) rather than lying flat.
    var isActive: Bool
    /// Runs top to bottom, so the pages sit side by side.
    var isVertical: Bool { frame.height > frame.width }
}

extension EnvironmentValues {
    /// True inside a side-by-side fold layout (vertical hinge), so children
    /// can size for half the width (e.g. the feelings grid drops to two
    /// columns). A horizontal hinge leaves each page full width.
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

private struct FoldKey: PreferenceKey {
    static let defaultValue: Fold? = nil
    static func reduce(value: inout Fold?, nextValue: () -> Fold?) {
        value = value ?? nextValue()
    }
}

extension View {
    /// Reports the hinge crossing this view (nil otherwise).
    /// The reserved-region API is iOS 27.1+; earlier systems never fold.
    func readsFold(_ fold: Binding<Fold?>) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: FoldKey.self, value: hinge(in: proxy))
            }
        }
        .onPreferenceChange(FoldKey.self) { fold.wrappedValue = $0 }
    }
}

private func hinge(in proxy: GeometryProxy) -> Fold? {
    guard #available(iOS 27.1, *) else { return nil }
    // Inactive regions too: the hinge is reported while the Duo lies flat,
    // so the two-page layout is already in place before it folds and
    // bending it changes nothing (HIG: avoid extreme layout changes when
    // folding). iPhone Duo has one fold.
    guard let region = proxy.reservedRegions(kind: .division, options: .includeInactive).first else { return nil }
    return Fold(frame: region.frame, isActive: region.isActive)
}

/// Places its first subview on the page before the hinge (left, or top) and
/// its second on the page after it (right, or bottom), each centred in its
/// page, nothing on the crease. A Layout (not a stack branch) so it can swap
/// in through AnyLayout without rebuilding the children — see
/// AdaptiveStepLayout.
struct FoldSplitLayout: Layout {
    var fold: Fold

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        if fold.isVertical {
            let width = proposal.width ?? fold.frame.maxX * 2
            let pageWidths = [fold.frame.minX, width - fold.frame.maxX].map { max($0, 0) }
            let heights = zip(subviews, pageWidths).map { subview, pageWidth in
                subview.sizeThatFits(ProposedViewSize(width: pageWidth, height: proposal.height)).height
            }
            return CGSize(width: width, height: proposal.height ?? heights.max() ?? 0)
        } else {
            // Inside a ScrollView the height proposal is open: tall enough
            // to put the second page entirely below the hinge.
            let sizes = subviews.prefix(2).map { $0.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)) }
            let width = proposal.width ?? sizes.map(\.width).max() ?? 0
            let below = sizes.count > 1 ? sizes[1].height : 0
            return CGSize(width: width, height: proposal.height ?? fold.frame.maxY + below)
        }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let pages: [CGRect]
        if fold.isVertical {
            pages = [
                CGRect(x: bounds.minX, y: bounds.minY, width: max(fold.frame.minX, 0), height: bounds.height),
                CGRect(x: bounds.minX + fold.frame.maxX, y: bounds.minY,
                       width: max(bounds.width - fold.frame.maxX, 0), height: bounds.height),
            ]
        } else {
            pages = [
                CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: max(fold.frame.minY, 0)),
                CGRect(x: bounds.minX, y: bounds.minY + fold.frame.maxY,
                       width: bounds.width, height: max(bounds.height - fold.frame.maxY, 0)),
            ]
        }
        for (subview, page) in zip(subviews.prefix(2), pages) {
            let size = subview.sizeThatFits(ProposedViewSize(width: page.width, height: page.height))
            subview.place(at: CGPoint(x: page.midX, y: page.midY), anchor: .center,
                          proposal: ProposedViewSize(width: page.width, height: size.height))
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
    func placedOffFold(_ fold: Fold?) -> some View {
        let bookPose = fold?.isActive == true && fold?.isVertical == true
        if #available(iOS 27.0, *) {
            presentationPlacement(bookPose ? .trailing : .automatic)
                .environment(\.keepSheetToolbarHorizontal, bookPose)
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
