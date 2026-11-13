import Core
import SwiftUI

/// The welcome's second screen (01-04, 01-08): why cleanup notes help and what one looks like, before iOS asks (01-05).
struct NotificationsAskScreen: View {
    let onTurnOn: () -> Void
    let onNotNow: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    // Home.dc.html line 242: a 72 pt well with a 34 pt bell.
    private static let wellSize: CGFloat = 72
    // Home.dc.html lines 243-244: 22 pt above the title, 10 pt above the explanation, which is at most 300 pt wide.
    private static let titleGap: CGFloat = 22
    private static let messageGap: CGFloat = 10
    private static let messageMaxWidth: CGFloat = 300
    // Home.dc.html lines 245-248: the sample note is 30 pt down, padded 14 by 16 pt with 22 pt corners; its app glyph
    // is 36 pt with 9 pt corners, 12 pt before the text. "At most one a day" is 10 pt under it.
    private static let noteTop: CGFloat = 30
    private static let noteVerticalPadding: CGFloat = 14
    private static let noteHorizontalPadding: CGFloat = 16
    private static let noteCornerRadius: CGFloat = 22
    private static let glyphSize: CGFloat = 36
    private static let glyphCornerRadius: CGFloat = 9
    private static let glyphGap: CGFloat = 12
    private static let footnoteTop: CGFloat = 10

    var body: some View {
        WelcomePage(
            primaryIdentifier: AccessibilityID.Welcome.turnOn,
            primaryTitle: Text("Turn on notifications", bundle: #bundle),
            onPrimary: onTurnOn
        ) {
            VStack(spacing: 0) {
                // The mock's 34 pt box draws a bell about 26 pt tall: Title 1's size. It follows Dynamic Type, and the well
                // grows with it.
                SymbolWell(
                    systemName: "bell",
                    font: Tokens.Typography.title1.weight(.regular),
                    foreground: Tokens.Color.textPrimary,
                    fill: Tokens.Color.bgWell,
                    size: Self.wellSize)
                Text("Know when\nit cleans up", bundle: #bundle)
                    .font(Tokens.Typography.title1)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .padding(.top, Self.titleGap)
                    .accessibilityAddTraits(.isHeader)
                Text("Expired scans move to Trash on their own. Get a short note when that happens.", bundle: #bundle)
                    .font(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    // At accessibility sizes the 300 pt cap would leave a word or two per line.
                    .frame(maxWidth: typeSize.isAccessibilitySize ? nil : Self.messageMaxWidth)
                    .padding(.top, Self.messageGap)
                sampleNote
                    .padding(.top, Self.noteTop)
                Text("At most one a day", bundle: #bundle)
                    .font(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .padding(.top, Self.footnoteTop)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        } secondary: {
            TextButton(identifier: AccessibilityID.Welcome.notNow, action: onNotNow) {
                Text("Not now", bundle: #bundle)
            }
        }
    }

    /// What a cleanup note looks like: the app's folder glyph, then the note's title and text.
    private var sampleNote: some View {
        HStack(alignment: .top, spacing: Self.glyphGap) {
            // Subheadline is the mock's 20 by 16 pt folder, and it follows Dynamic Type.
            Image(systemName: "folder.fill")
                .font(Tokens.Typography.subheadline)
                .foregroundStyle(Tokens.Color.bgGrouped)
                .frame(minWidth: Self.glyphSize, minHeight: Self.glyphSize)
                .background(Tokens.Color.textPrimary, in: .rect(cornerRadius: Self.glyphCornerRadius))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("Cleaned up 3 receipts", bundle: #bundle)
                    .font(Tokens.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(Tokens.Color.textPrimary)
                Text("They’re in Trash for 30 days if you need them.", bundle: #bundle)
                    .font(Tokens.Typography.subheadline)
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .multilineTextAlignment(.leading)
        .padding(.vertical, Self.noteVerticalPadding)
        .padding(.horizontal, Self.noteHorizontalPadding)
        .background(Tokens.Color.bgWell, in: .rect(cornerRadius: Self.noteCornerRadius))
        .accessibilityElement(children: .combine)
    }
}
