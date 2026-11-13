import Core
import SwiftUI

/// The welcome's first screen (01-03, 01-07): the New York title, four points, then Continue.
struct WelcomeScreen: View {
    let onContinue: () -> Void

    /// Home.dc.html line 216: each point's symbol is centred in a 36 pt column, which grows with the symbol, so every
    /// point's text starts at the same place whatever its symbol's width.
    @ScaledMetric(relativeTo: .title2) private var symbolColumn: CGFloat = 36

    // Home.dc.html lines 215-217: 44 pt from the title to the points, 28 pt between points; each point's symbol sits
    // 2 pt down, 16 pt before its text, whose two lines are 2 pt apart.
    private static let pointsTop: CGFloat = 44
    private static let pointGap: CGFloat = 28
    private static let symbolTop: CGFloat = 2
    private static let symbolGap: CGFloat = 16
    private static let lineGap: CGFloat = 2

    var body: some View {
        WelcomePage(
            primaryIdentifier: AccessibilityID.Welcome.continue,
            primaryTitle: Text("Continue", bundle: #bundle),
            onPrimary: onContinue
        ) {
            VStack(spacing: 0) {
                Text("Welcome to\nFiling Cabinet", bundle: #bundle)
                    .font(Tokens.Typography.largeTitle)
                    .tracking(Tokens.Typography.largeTitleTracking)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: Self.pointGap) {
                    point(
                        "text.viewfinder",
                        title: Text("Scan in one tap", bundle: #bundle),
                        detail: Text("Point your camera at any paper. Several pages make one scan.", bundle: #bundle))
                    point(
                        "folder",
                        title: Text("Sorted into collections", bundle: #bundle),
                        detail: Text("Every scan goes into a collection, so it’s easy to find later.", bundle: #bundle))
                    point(
                        "clock",
                        title: Text("Cleans up after itself", bundle: #bundle),
                        detail: Text("Things you only need for a while expire on their own.", bundle: #bundle))
                    point(
                        "lock",
                        title: Text("Private by design", bundle: #bundle),
                        detail: Text(
                            "No account. Scans stay on your iPhone and in your iCloud backup.", bundle: #bundle))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Self.pointsTop)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One point: its symbol, then a headline and a line or two under it. Read as one element.
    private func point(_ symbol: String, title: Text, detail: Text) -> some View {
        HStack(alignment: .top, spacing: Self.symbolGap) {
            // The mock draws its 30 pt symbol box with a glyph about 24 pt across: Title 2's size. It follows Dynamic Type.
            Image(systemName: symbol)
                .font(Tokens.Typography.title2.weight(.regular))
                .foregroundStyle(Tokens.Color.textPrimary)
                .frame(width: symbolColumn)
                .padding(.top, Self.symbolTop)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Self.lineGap) {
                title
                    .font(Tokens.Typography.headline)
                    .foregroundStyle(Tokens.Color.textPrimary)
                detail
                    .font(Tokens.Typography.subheadline)
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
