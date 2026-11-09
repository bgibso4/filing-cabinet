import Core
import ScreenModels
import SwiftUI
import UIKit

/// Settings from Home's gear (10-01): Collections and Notifications, then the footer. The Apple Intelligence row comes
/// with Plan 3 and Send feedback with Plan 5.
public struct SettingsView: View {
    private let model: SettingsModel
    private let onOpenCollections: () -> Void

    // Settings2.dc.html line 30: 22 pt above each group.
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

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    public init(model: SettingsModel, onOpenCollections: @escaping () -> Void) {
        self.model = model
        self.onOpenCollections = onOpenCollections
    }

    public var body: some View {
        HeaderScrollView(
            title: Text("Settings", bundle: #bundle),
            subtitle: nil,
            identifier: AccessibilityID.Settings.header,
            rest: .small
        ) {
            VStack(alignment: .leading, spacing: 0) {
                group { collectionsRow }
                    .padding(.top, Self.groupGap)
                group { notificationsRow }
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
        .background(Tokens.Color.bgGrouped)
        .task { await model.refreshAuthorization() }
        // Someone may come back from iPhone Settings having turned notifications on or off.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refreshAuthorization() } }
        }
    }

    private func group(@ViewBuilder _ rows: () -> some View) -> some View {
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

    /// The switch carries the name and note for VoiceOver; the text beside it is only drawn, so it can sit above the
    /// switch at accessibility sizes.
    private var notificationsRow: some View {
        row(icon: "bell") {
            notificationsText
                .accessibilityHidden(true)
        } trailing: {
            Toggle(isOn: notificationsOn) { notificationsText }
                .toggleStyle(MonochromeToggleStyle())
                .accessibilityIdentifier(AccessibilityID.Settings.notifications)
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
    /// under the text, so a name never breaks mid-word (12-05).
    private func row(
        icon: String, @ViewBuilder text: () -> some View, @ViewBuilder trailing: () -> some View
    ) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Tokens.Spacing.s2) {
                    text()
                    HStack(spacing: Tokens.Spacing.s2) {
                        Spacer(minLength: 0)
                        trailing()
                    }
                }
            } else {
                HStack(spacing: Tokens.Spacing.s3) {
                    Image(systemName: icon)
                        .font(Tokens.Typography.body)
                        .imageScale(.large)
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .frame(width: Self.iconWidth)
                        .accessibilityHidden(true)
                    HStack(spacing: Tokens.Spacing.s2) {
                        text()
                        Spacer(minLength: 0)
                        trailing()
                    }
                }
            }
        }
        .padding(.vertical, Self.rowVerticalPadding)
        .padding(.leading, Tokens.Spacing.s4)
        .padding(.trailing, Self.rowTrailingPadding)
        .frame(minHeight: Self.rowMinHeight)
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
}
