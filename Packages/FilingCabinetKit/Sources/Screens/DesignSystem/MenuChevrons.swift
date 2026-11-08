import SwiftUI

/// The up-down chevrons at the end of a row that opens a menu.
struct MenuChevrons: View {
    var body: some View {
        Image(systemName: "chevron.up.chevron.down")
            .font(Tokens.Typography.footnote.weight(.semibold))
            .foregroundStyle(Tokens.Color.textSecondary)
            .accessibilityHidden(true)
    }
}
