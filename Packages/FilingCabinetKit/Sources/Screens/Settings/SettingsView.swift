import Core
import ScreenModels
import SwiftUI
import UIKit

/// Settings from Home's gear (10-01): Collections, Appearance, then Apple Intelligence and Notifications with the line
/// about Apple Intelligence under them (Plan 5's demo), then Send feedback and the Privacy policy (Plan 6), then the footer.
public struct SettingsView: View {
    let model: SettingsModel
    private let onOpenCollections: () -> Void

    // Settings2.dc.html line 30: 22 pt above each group; the first one is 22 pt under the bar now the title is in it.
    private static let groupGap: CGFloat = 22
    // Settings2.dc.html line 32: rows are at least 50 pt tall.
    private static let rowMinHeight: CGFloat = 50
    // Settings2.dc.html line 33: the icon column is 24 pt wide.
    private static let iconWidth: CGFloat = 24
    // Settings2.dc.html line 34: 6 pt above and below the text, 14 pt after it.
    private static let rowVerticalPadding: CGFloat = 6
    private static let rowTrailingPadding: CGFloat = 14
    // Settings2.dc.html line 43: the footer is 28 pt under the last group.
    private static let footerTopGap: CGFloat = 28
    // Plan 5's demo (`.progress`): the bar under the reading line is 4 pt tall with 2 pt corners.
    private static let progressHeight: CGFloat = 4
    private static let progressRadius: CGFloat = 2

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.openURL) var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State var feedbackDraft: URL?

    public init(model: SettingsModel, onOpenCollections: @escaping () -> Void) {
        self.model = model
        self.onOpenCollections = onOpenCollections
    }

    public var body: some View {
        HeaderScrollView(
            title: Text("Settings", bundle: #bundle),
            subtitle: nil,
            rest: .small
        ) {
            VStack(alignment: .leading, spacing: 0) {
                group { collectionsRow }
                    .padding(.top, Self.groupGap)
                group { appearanceRow }
                    .padding(.top, Self.groupGap)
                group {
                    intelligenceRow
                    notificationsRow
                }
                .padding(.top, Self.groupGap)
                if let footer = model.intelligence.footer {
                    intelligenceFooter(footer, progress: model.intelligence.progress)
                        .padding(.top, Tokens.Spacing.s2)
                        .padding(.horizontal, Tokens.Spacing.s4)
                }
                feedbackGroup
                    .padding(.top, Self.groupGap)
                Text(model.footer)
                    .font(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Self.footerTopGap)
            }
            .padding(.horizontal, Tokens.Spacing.s4)
            .padding(.bottom, Tokens.Spacing.s8)
        }
        // It fits the screen: a bounce shows no scroll bar (phone check F4).
        .scrollIndicators(.hidden)
        .background(Tokens.Color.bgGrouped)
        .mailComposer(url: $feedbackDraft)
        .task { await model.refreshAuthorization() }
        // Someone may come back from iPhone Settings having turned notifications on or off.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refreshAuthorization() } }
        }
    }

    func group(@ViewBuilder _ rows: () -> some View) -> some View {
        VStack(spacing: 0, content: rows)
            .background(Tokens.Color.bgSurface, in: .rect(cornerRadius: Tokens.Radius.surface))
    }

    private var collectionsRow: some View {
        Button(action: onOpenCollections) {
            row(icon: "folder") {
                Text("Collections", bundle: #bundle)
                    .font(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Color.textPrimary)
            } trailing: {
                Text(model.collectionsCount, format: .number)
                    .font(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Color.textSecondary)
                DisclosureChevron()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.Settings.collections)
    }

    /// The row, with a clear system menu button over it as the one accessibility element (as "Keep scans for").
    private var appearanceRow: some View {
        row(icon: "circle.lefthalf.filled") {
            Text("Appearance", bundle: #bundle)
                .font(Tokens.Typography.body)
                .foregroundStyle(Tokens.Color.textPrimary)
        } trailing: {
            Text(model.appearance.title)
                .font(Tokens.Typography.body)
                .foregroundStyle(Tokens.Color.textSecondary)
            MenuChevrons()
        }
        .accessibilityHidden(true)
        .overlay {
            MenuButton(
                label: String(localized: "Appearance", bundle: #bundle),
                value: model.appearance.title,
                identifier: AccessibilityID.Settings.appearance,
                menu: appearanceMenu)
        }
    }

    /// System, Light and Dark, with a check on the current one.
    private func appearanceMenu() -> UIMenu {
        UIMenu(
            children: AppearanceChoice.allCases.map { choice in
                let action = UIAction(title: choice.title) { _ in model.setAppearance(choice) }
                action.state = choice == model.appearance ? .on : .off
                return action
            })
    }

    /// The switch carries the name and note for VoiceOver; the text beside it is only drawn, so it can sit above the
    /// switch at accessibility sizes.
    private var notificationsRow: some View {
        row(icon: "bell", showsSeparator: true) {
            notificationsText
                .accessibilityHidden(true)
        } trailing: {
            Toggle(isOn: notificationsOn) { notificationsText }
                .toggleStyle(MonochromeToggleStyle())
                .accessibilityIdentifier(AccessibilityID.Settings.notifications)
        }
    }

    /// Like Notifications: the switch carries the name and note. Without Apple Intelligence it is off and dimmed (10-06).
    private var intelligenceRow: some View {
        let row = model.intelligence
        return self.row(icon: "sparkles") {
            intelligenceText(row)
                .accessibilityHidden(true)
        } trailing: {
            Toggle(isOn: intelligenceOn) { intelligenceText(row) }
                .toggleStyle(MonochromeToggleStyle())
                .disabled(!row.isAvailable)
                .accessibilityIdentifier(AccessibilityID.Settings.intelligence)
        }
    }

    private func intelligenceText(_ row: IntelligenceRow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Apple Intelligence", bundle: #bundle)
                .font(Tokens.Typography.body)
                .foregroundStyle(Tokens.Color.textPrimary)
            Text(row.subtitle)
                .font(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Color.textSecondary)
        }
    }

    /// While older scans are read, how far it has got, with a thin bar; otherwise the privacy line.
    private func intelligenceFooter(_ footer: String, progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s2) {
            Text(footer)
                .font(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let progress {
                progressBar(progress)
                    // The line above already says how far it has got.
                    .accessibilityHidden(true)
            }
        }
    }

    private func progressBar(_ progress: Double) -> some View {
        RoundedRectangle(cornerRadius: Self.progressRadius)
            .fill(Tokens.Color.bgFill)
            .frame(height: Self.progressHeight)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: Self.progressRadius)
                        .fill(Tokens.Color.textSecondary)
                        .frame(width: proxy.size.width * progress)
                }
            }
    }

    private var notificationsText: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notifications", bundle: #bundle)
                .font(Tokens.Typography.body)
                .foregroundStyle(Tokens.Color.textPrimary)
            Text(model.notificationsNote)
                .font(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Color.textSecondary)
        }
    }

    /// An icon, the text, then the value or switch. At accessibility sizes the icon goes and the value or switch moves
    /// under the text, so a name never breaks mid-word (12-05). `showsSeparator` draws a hairline above the row, from
    /// where its text starts to the group's edge (10-01).
    func row(
        icon: String,
        showsSeparator: Bool = false,
        @ViewBuilder text: () -> some View,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                framed(
                    VStack(alignment: .leading, spacing: Tokens.Spacing.s2) {
                        text()
                        HStack(spacing: Tokens.Spacing.s2) {
                            Spacer(minLength: 0)
                            trailing()
                        }
                    },
                    showsSeparator: showsSeparator)
            } else {
                HStack(spacing: Tokens.Spacing.s3) {
                    Image(systemName: icon)
                        .font(Tokens.Typography.body)
                        .imageScale(.large)
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .frame(width: Self.iconWidth)
                        .accessibilityHidden(true)
                    framed(
                        HStack(spacing: Tokens.Spacing.s2) {
                            text()
                            Spacer(minLength: 0)
                            trailing()
                        },
                        showsSeparator: showsSeparator)
                }
            }
        }
        .padding(.leading, Tokens.Spacing.s4)
    }

    private var intelligenceOn: Binding<Bool> {
        Binding(get: { model.intelligence.isOn }, set: { model.setIntelligence($0) })
    }

    /// The switch shows what the model says. Turning it on while iOS blocks notes sends the person to iPhone Settings,
    /// the only place that can change it; the switch stays off.
    private var notificationsOn: Binding<Bool> {
        Binding(
            get: { model.notificationsSwitchIsOn },
            set: { isOn in
                Task {
                    guard await model.setNotifications(isOn) == .openSystemSettings,
                        let url = URL(string: UIApplication.openNotificationSettingsURLString)
                    else { return }
                    openURL(url)
                }
            })
    }

    /// A row's text and value: padded, at least 50 pt tall, with the separator on its top edge.
    private func framed(_ content: some View, showsSeparator: Bool) -> some View {
        content
            .padding(.vertical, Self.rowVerticalPadding)
            .padding(.trailing, Self.rowTrailingPadding)
            .frame(minHeight: Self.rowMinHeight)
            .overlay(alignment: .top) {
                if showsSeparator { Hairline() }
            }
    }
}
