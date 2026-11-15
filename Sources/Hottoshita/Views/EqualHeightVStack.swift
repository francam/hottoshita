import SwiftUI

/// A vertical stack whose rows all take the height of the tallest one.
struct EqualHeightVStack: Layout {
    var spacing: CGFloat

    private func rowHeight(_ subviews: Subviews, width: CGFloat?) -> CGFloat {
        subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }.max() ?? 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = rowHeight(subviews, width: proposal.width)
        let width = proposal.width
            ?? subviews.map { $0.sizeThatFits(ProposedViewSize(width: nil, height: height)).width }.max() ?? 0
        let gaps = spacing * CGFloat(max(subviews.count - 1, 0))
        return CGSize(width: width, height: height * CGFloat(subviews.count) + gaps)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let height = rowHeight(subviews, width: bounds.width)
        var y = bounds.minY
        for subview in subviews {
            subview.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: height))
            y += height + spacing
        }
    }
}
