import Core
import ScreenModels
import SwiftUI
import UIKit

/// One collection's settings (10-03): its count and "Keep scans for", whose menu checks the current choice (10-04).
/// Shortening it so that scans go to Trash now asks first (10-05).
public struct CollectionSettingsView: View {
    private let model: CollectionSettingsModel

    // Settings2.dc.html lines 17 and 74: the title starts 12 pt under the 44 pt back button; the system bar is 10 pt
    // taller than the mock's button (as on Trash).
    private static let titleTopGap: CGFloat = 2
    // Settings2.dc.html line 75: a 36 pt badge with a 20 pt symbol, 10 pt before the title.
    private static let badgeDiameter: CGFloat = 36
    private static let badgeSymbol: CGFloat = 20
    private static let badgeGap: CGFloat = 10
    // Settings2.dc.html line 76: 2 pt between the title and the count.
    private static let countGap: CGFloat = 2
    // Settings2.dc.html lines 76 and 92: "Expiry" starts 24 pt under the count (6 + 18), 6 pt above the row.
    private static let sectionTopGap: CGFloat = 24
    private static let sectionBottomGap: CGFloat = 6
    // Settings2.dc.html line 94: the row is 50 pt tall.
    private static let rowMinHeight: CGFloat = 50
    // Settings2.dc.html line 100: the note is 6 pt under the row.
    private static let noteTopGap: CGFloat = 6

    @Environment(\.dynamicTypeSize) private var typeSize

    public init(model: CollectionSettingsModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, Self.titleTopGap)
                Text("Expiry", bundle: #bundle)
                    .font(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, Tokens.Spacing.s4)
                    .padding(.top, Self.sectionTopGap)
                    .padding(.bottom, Self.sectionBottomGap)
                keepScansFor
                Text(model.note)
                    .font(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .padding(.horizontal, Tokens.Spacing.s4)
                    .padding(.top, Self.noteTopGap)
            }
            .padding(.horizontal, Tokens.Spacing.s4)
            .padding(.bottom, Tokens.Spacing.s8)
        }
        .background(Tokens.Color.bgGrouped)
        // The system bar, clear, as on the grids: the back button is the system's glass one and swipe back works.
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert(
            model.confirmation?.title ?? "",
            // Its buttons say what happens; dismissing it is only ever one of them, so the binding never clears it.
            isPresented: Binding(get: { model.confirmation != nil }, set: { _ in }),
            presenting: model.confirmation
        ) { confirmation in
            Button(role: .cancel, action: model.cancel) { Text("Cancel", bundle: #bundle) }
            Button(role: .destructive, action: model.confirm) { Text(confirmation.confirmTitle) }
        } message: { confirmation in
            Text(confirmation.message)
        }
        .editAlert(model.editAlert, dismiss: model.dismissEditAlert)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Self.countGap) {
            HStack(spacing: Self.badgeGap) {
                CollectionBadge(
                    collection: model.collection, diameter: Self.badgeDiameter, symbolSize: Self.badgeSymbol)
                Text(model.title)
                    .font(Tokens.Typography.largeTitle)
                    .tracking(Tokens.Typography.largeTitleTracking)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(model.countLine)
                .font(Tokens.Typography.subheadline)
                .foregroundStyle(Tokens.Color.textSecondary)
        }
    }

    /// The row, with a clear system menu button over it as the one accessibility element.
    private var keepScansFor: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 0) {
                    label
                    HStack(spacing: Tokens.Spacing.s3) {
                        value
                        Spacer(minLength: 0)
                        MenuChevrons()
                    }
                }
            } else {
                HStack(spacing: Tokens.Spacing.s3) {
                    label
                    Spacer(minLength: 0)
                    value
                    MenuChevrons()
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.s4)
        .padding(.vertical, Tokens.Spacing.s2)
        .frame(minHeight: Self.rowMinHeight)
        .background(Tokens.Color.bgSurface, in: .rect(cornerRadius: Tokens.Radius.surface))
        .accessibilityHidden(true)
        .overlay {
            MenuButton(
                label: String(localized: "Keep scans for", bundle: #bundle),
                value: model.lifespanValue,
                identifier: AccessibilityID.CollectionSettings.keepScansFor,
                menu: menu)
        }
    }

    private var label: some View {
        Text("Keep scans for", bundle: #bundle)
            .font(Tokens.Typography.body)
            .foregroundStyle(Tokens.Color.textPrimary)
    }

    private var value: some View {
        Text(model.lifespanValue)
            .font(Tokens.Typography.body)
            .foregroundStyle(Tokens.Color.textSecondary)
    }

    /// Every lifespan, shortest first, with a check on the current one.
    private func menu() -> UIMenu {
        UIMenu(
            children: model.choices.map { choice in
                let action = UIAction(title: choice.title) { _ in model.choose(choice.lifespan) }
                action.state = choice.isCurrent ? .on : .off
                return action
            })
    }
}
