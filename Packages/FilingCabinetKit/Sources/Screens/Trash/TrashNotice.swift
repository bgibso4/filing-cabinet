import Core
import SwiftUI

/// The note first in Trash's content, above the tiles, saying how long scans stay (E8, as Passwords' Recently Deleted):
/// a card the width of the content, in the secondary colour. It scrolls with the tiles and reads as plain text.
struct TrashNotice: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Tokens.Typography.subheadline)
            .foregroundStyle(Tokens.Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Spacing.s4)
            // The same card as Settings' groups: bg-surface on bg-grouped, the surface radius.
            .background(Tokens.Color.bgSurface, in: .rect(cornerRadius: Tokens.Radius.surface))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AccessibilityID.Trash.notice)
    }
}
