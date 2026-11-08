import SwiftUI

/// The chevron at the end of a row that opens another screen. Never on buttons.
struct DisclosureChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(Tokens.Typography.footnote.weight(.semibold))
            .foregroundStyle(Tokens.Color.chevron)
            .accessibilityHidden(true)
    }
}
