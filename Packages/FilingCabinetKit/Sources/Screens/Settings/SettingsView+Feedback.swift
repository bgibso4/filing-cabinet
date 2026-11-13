import Core
import ScreenModels
import SwiftUI

/// Settings' last group: Send feedback and the Privacy policy (Plan 6). Apart from `SettingsView` to keep that struct
/// within the lint's body length.
extension SettingsView {
    var feedbackGroup: some View {
        group {
            feedbackRow
            privacyRow
        }
    }

    /// Opens a mail draft with the app and iPhone details; with no mail app, an alert gives the address.
    private var feedbackRow: some View {
        Button {
            model.feedbackOpened()
            feedbackDraft = model.feedbackURL
        } label: {
            row(icon: "envelope") {
                Text("Send feedback", bundle: #bundle)
                    .font(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Color.textPrimary)
            } trailing: {
                DisclosureChevron()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.Settings.feedback)
    }

    /// Opens the policy in Safari, so it ends in an arrow, not a chevron.
    private var privacyRow: some View {
        Button {
            openURL(model.privacyURL)
        } label: {
            row(icon: "hand.raised", showsSeparator: true) {
                Text("Privacy policy", bundle: #bundle)
                    .font(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Color.textPrimary)
            } trailing: {
                Image(systemName: "arrow.up.right")
                    .font(Tokens.Typography.footnote.weight(.semibold))
                    .foregroundStyle(Tokens.Color.chevron)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isLink)
        .accessibilityIdentifier(AccessibilityID.Settings.privacy)
    }
}
