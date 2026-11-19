import Core
import SwiftUI

/// SPIKE (#45, option A3), throwaway: a glass Search field beside a round, filled Scan button with its symbol alone.
/// No tests, no large-text handling. Not for merging.
struct HomeBottomBar: View {
    let canScan: Bool
    let onScan: () -> Void
    let onSearch: () -> Void

    // PillButton's filled height: both controls are as tall as today's Scan.
    private static let height: CGFloat = 56

    @Environment(\.captureLayerIsUp) private var captureLayerIsUp

    var body: some View {
        // `hidden()` as ScanBarLayout does: it takes the bar out of the accessibility tree under the capture layer.
        if captureLayerIsUp { bar.hidden() } else { bar }
    }

    private var bar: some View {
        HStack(spacing: Tokens.Spacing.s3) {
            search
            scan
        }
        .padding(.horizontal, Tokens.Spacing.s4)
    }

    private var search: some View {
        Button(action: onSearch) {
            HStack(spacing: Tokens.Spacing.s2) {
                Image(systemName: "magnifyingglass")
                    .accessibilityHidden(true)
                Text("Search", bundle: #bundle)
                Spacer(minLength: 0)
            }
            .font(Tokens.Typography.body)
            .foregroundStyle(Tokens.Color.textSecondary)
            .padding(.horizontal, Tokens.Spacing.s4)
            .frame(minHeight: Self.height)
            .glassEffect(.regular.interactive(), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(UnfadedButtonStyle())
        .accessibilityIdentifier(AccessibilityID.Home.search)
    }

    private var scan: some View {
        Button(action: onScan) {
            Image(systemName: "text.viewfinder")
                .font(Tokens.Typography.headline)
                .imageScale(.large)
                .foregroundStyle(canScan ? Tokens.Color.bgGrouped : Tokens.Color.textSecondary)
                .frame(width: Self.height, height: Self.height)
                .glassEffect(canScan ? .regular.tint(Tokens.Color.tint).interactive() : .regular, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(UnfadedButtonStyle())
        .accessibilityLabel(Text("Scan", bundle: #bundle))
        .accessibilityIdentifier(AccessibilityID.Home.scan)
        .disabled(!canScan)
    }
}
