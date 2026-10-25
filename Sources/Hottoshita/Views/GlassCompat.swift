import SwiftUI

// Liquid Glass on iOS 26+, the pre-26 look below it. The deployment target
// stays at iOS 16, so every custom glass call goes through one of these —
// one #available gate per style instead of branches spread across views.
// System chrome (bars, sheets, alerts) gets glass on 26+ by itself.

extension View {
    /// The screen's one primary action: tinted prominent glass.
    @ViewBuilder
    func primaryActionStyle(accent: Color) -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent).tint(accent)
        } else {
            buttonStyle(.borderedProminent).tint(accent)
        }
    }

    /// Secondary actions. On glass the material stays untinted — tint is
    /// reserved for the primary action — and the theme colour moves to the
    /// label instead.
    @ViewBuilder
    func secondaryActionStyle(accent: Color) -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass).foregroundStyle(accent)
        } else {
            buttonStyle(.bordered).tint(accent)
        }
    }

    /// A toolbar button that isn't the confirming action (e.g. Cancel).
    /// Toolbar items are already glass on 26+, so no button style there —
    /// just the theme colour on the label. Before 26, the filled pill the
    /// app has always used (its label defaults to white).
    @ViewBuilder
    func toolbarSecondaryStyle(accent: Color) -> some View {
        if #available(iOS 26.0, *) {
            foregroundStyle(accent)
        } else {
            buttonStyle(.borderedProminent).tint(accent)
        }
    }

    /// Background for a tappable answer tile. Selected tiles are filled
    /// with the accent; unselected ones get an accent outline so the tile's
    /// edge clears 3:1 against the background (the glass rim and the old
    /// grouped fill alone measured 1.1–1.7:1).
    @ViewBuilder
    func answerTileBackground(selected: Bool, accent: Color, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        if #available(iOS 26.0, *) {
            // Outline before the glass: it becomes part of the glass's content,
            // drawn on top of the material. Applied after, the glass rim
            // covered most of it (measured ~0.7pt, 2.6:1).
            overlay { shape.strokeBorder(accent, lineWidth: selected ? 0 : 2) }
                .glassEffect(selected ? .regular.tint(accent).interactive() : .regular.interactive(), in: shape)
        } else {
            background(selected ? accent : Color(.systemGroupedBackground), in: shape)
                .overlay { shape.strokeBorder(accent, lineWidth: selected ? 0 : 2) }
        }
    }
}

/// Groups nearby glass so it renders together (glass can't sample other
/// glass). `spacing` 0 keeps shapes from blending across the layout gaps.
/// A plain pass-through before iOS 26.
struct GlassGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 0) { content }
        } else {
            content
        }
    }
}
