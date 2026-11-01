import Core
import SwiftUI

/// The Scan pill: graphite in light, near-white in dark, always labelled "Scan".
public struct ScanButton: View {
    private let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var height = 52

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.s2) {
                Image(systemName: "text.viewfinder")
                Text("Scan", bundle: #bundle)
            }
            .font(Tokens.Typography.headline)
            .foregroundStyle(Tokens.Color.bgGrouped)
            .padding(.horizontal, 30)
            .frame(minHeight: height)
            .background(Tokens.Color.tint, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.scanButton)
    }
}

#Preview("Light") {
    ScanButton {}.padding()
}

#Preview("Dark") {
    ScanButton {}.padding().background(Tokens.Color.bgGrouped).preferredColorScheme(.dark)
}
