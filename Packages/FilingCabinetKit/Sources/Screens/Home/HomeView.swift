import Core
import ScreenModels
import SwiftUI

/// Home on first launch: the five collections and the Scan button.
public struct HomeView: View {
    private let model: HomeModel
    private let onScan: () -> Void

    // Home.dc.html: gap above "Collections" on first launch.
    private static let collectionsTopGap: CGFloat = 18
    // Home.dc.html: the fade behind the pill is solid from 38% of its height.
    private static let fadeSolidLocation: Double = 0.38

    public init(model: HomeModel, onScan: @escaping () -> Void) {
        self.model = model
        self.onScan = onScan
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Filing Cabinet", bundle: #bundle)
                    .font(Tokens.Typography.largeTitle)
                    .tracking(Tokens.Typography.largeTitleTracking)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .frame(minHeight: Tokens.Spacing.tapMin)
                    .accessibilityAddTraits(.isHeader)
                Text("Collections", bundle: #bundle)
                    .font(Tokens.Typography.title2)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .frame(minHeight: Tokens.Spacing.tapMin)
                    .padding(.top, Self.collectionsTopGap)
                    .accessibilityAddTraits(.isHeader)
                collections
            }
            .padding(.horizontal, Tokens.Spacing.s4)
        }
        .background(Tokens.Color.bgGrouped)
        .safeAreaInset(edge: .bottom, spacing: 0) { floatingScan }
    }

    private var collections: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                HomeRowView(row: row, showsSeparator: index > 0)
            }
        }
        .background(Tokens.Color.bgSurface, in: .rect(cornerRadius: Tokens.Radius.surface))
    }

    /// The button floats at the bottom centre. As a safe-area inset it pushes the scroll content up by its real size,
    /// and the fade of the screen background sits behind it.
    private var floatingScan: some View {
        ScanButton(action: onScan)
            .padding(.top, Tokens.Spacing.s4)
            .frame(maxWidth: .infinity)
            .background {
                LinearGradient(
                    stops: [
                        .init(color: Tokens.Color.bgGrouped.opacity(0), location: 0),
                        .init(color: Tokens.Color.bgGrouped, location: Self.fadeSolidLocation),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            }
    }
}

#Preview("Light") {
    HomeView(model: HomeModel(), onScan: {})
}

#Preview("Dark") {
    HomeView(model: HomeModel(), onScan: {}).preferredColorScheme(.dark)
}

#Preview("Accessibility 5") {
    HomeView(model: HomeModel(), onScan: {}).dynamicTypeSize(.accessibility5)
}
