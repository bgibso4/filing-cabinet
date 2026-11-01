import Core
import ScreenModels
import SwiftUI

/// Home on first launch: the five collections and the Scan button.
public struct HomeView: View {
    private let model: HomeModel
    private let onScan: () -> Void

    public init(model: HomeModel, onScan: @escaping () -> Void) {
        self.model = model
        self.onScan = onScan
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Filing Cabinet", bundle: #bundle)
                    .font(Tokens.Typography.largeTitle)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .frame(minHeight: Tokens.Spacing.tapMin)
                    .accessibilityAddTraits(.isHeader)
                Text("Collections", bundle: #bundle)
                    .font(Tokens.Typography.title2)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .frame(minHeight: Tokens.Spacing.tapMin)
                    .padding(.top, 18)
                    .accessibilityAddTraits(.isHeader)
                collections
            }
            .padding(.horizontal, Tokens.Spacing.s4)
        }
        .contentMargins(.bottom, 130, for: .scrollContent)
        .background(Tokens.Color.bgGrouped)
        .overlay(alignment: .bottom) { floatingScan }
    }

    private var collections: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                HomeRowView(row: row, showsSeparator: index > 0)
            }
        }
        .background(Tokens.Color.bgSurface, in: .rect(cornerRadius: Tokens.Radius.surface))
    }

    /// The button floats at the bottom centre over a fade of the screen background.
    private var floatingScan: some View {
        ScanButton(action: onScan)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
            .background(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: Tokens.Color.bgGrouped.opacity(0), location: 0),
                        .init(color: Tokens.Color.bgGrouped, location: 0.62),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 128)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea(edges: .bottom)
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
