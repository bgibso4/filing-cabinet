import Core
import SwiftUI

/// The Scan pill: graphite in light, near-white in dark, always labelled "Scan".
struct ScanButton: View {
    private let action: () -> Void

    // Home.dc.html: the pill is 52 pt tall, 64 pt at the large-text variant, and never grows past that.
    private static let baseHeight: CGFloat = 52
    private static let maxHeight: CGFloat = 64
    // Home.dc.html: horizontal padding inside the pill.
    private static let horizontalPadding: CGFloat = 30

    @ScaledMetric(relativeTo: .body) private var scaledHeight = baseHeight

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.s2) {
                Image(systemName: "text.viewfinder")
                Text("Scan", bundle: #bundle)
            }
            .font(Tokens.Typography.headline)
            .foregroundStyle(Tokens.Color.bgGrouped)
            .padding(.horizontal, Self.horizontalPadding)
            .frame(minHeight: min(scaledHeight, Self.maxHeight))
            .background(Tokens.Color.tint, in: .capsule)
            // One element for the whole pill, so the audit measures the text against the pill and not against a
            // frame that is exactly the glyphs.
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Home.scan)
    }
}

#Preview("Light") {
    ScanButton {}.padding()
}

#Preview("Dark") {
    ScanButton {}.padding().background(Tokens.Color.bgGrouped).preferredColorScheme(.dark)
}
