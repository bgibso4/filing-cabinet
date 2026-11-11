import Library
import SwiftUI

/// Share as a 56 pt glass circle: the viewer's bar (06-01) and a grid's select bar (B12, A1). Hands `items` to the share
/// sheet, each with its preview.
struct ShareCircle: View {
    let items: [ScanPDF]
    let preview: (ScanPDF) -> SharePreview<Never, Never>
    let identifier: String

    // ScanView.dc.html line 263 and .superpowers/plandoc/p4/index.html lines 37-38: a 56 pt circle with a 23-24 pt
    // glyph; Title 2 is the nearest token.
    static var diameter: CGFloat { 56 }
    static var font: Font { Tokens.Typography.title2.weight(.regular) }

    var body: some View {
        ShareLink(
            items: items,
            preview: preview,
            label: { GlassCircleLabel(systemImage: "square.and.arrow.up", font: Self.font, diameter: Self.diameter) }
        )
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Share", bundle: #bundle))
        .accessibilityIdentifier(identifier)
    }
}
