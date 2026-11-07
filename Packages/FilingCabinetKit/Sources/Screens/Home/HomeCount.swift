import SwiftUI

/// A scan count on a Home row: secondary colour, fixed-width digits that roll when the number changes.
struct HomeCount: View {
    let count: Int

    var body: some View {
        Text(count, format: .number)
            .font(Tokens.Typography.body)
            .monospacedDigit()
            .contentTransition(.numericText())
            .foregroundStyle(Tokens.Color.textSecondary)
    }
}
