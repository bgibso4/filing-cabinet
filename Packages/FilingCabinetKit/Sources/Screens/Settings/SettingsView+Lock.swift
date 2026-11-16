import Core
import ScreenModels
import SwiftUI

/// Lock with Face ID and the line under it (library-lock mocks, Mock 2), between Apple Intelligence's group and Send
/// feedback.
extension SettingsView {
    var lockSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            group { lockRow }
            footnote(model.lockRow.footer)
                .padding(.top, Tokens.Spacing.s2)
                .padding(.horizontal, Tokens.Spacing.s4)
        }
    }

    /// Like Apple Intelligence: the switch carries the name and note. With no passcode on the phone it is off and
    /// dimmed, and the name is greyed (Mock 2, `.row.disabled`). Turning it either way asks Face ID first; the switch
    /// shows what the model then says.
    private var lockRow: some View {
        let row = model.lockRow
        return self.row(icon: "faceid") {
            lockText(row)
                .accessibilityHidden(true)
        } trailing: {
            Toggle(isOn: lockOn) { lockText(row) }
                .toggleStyle(MonochromeToggleStyle())
                .disabled(!row.isEnabled)
                .accessibilityIdentifier(AccessibilityID.Settings.lockSwitch)
        }
    }

    private func lockText(_ row: LockRow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Lock with Face ID", bundle: #bundle)
                .font(Tokens.Typography.body)
                .foregroundStyle(row.isEnabled ? Tokens.Color.textPrimary : Tokens.Color.textTertiary)
            Text(row.subtitle)
                .font(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Color.textSecondary)
        }
    }

    private var lockOn: Binding<Bool> {
        Binding(get: { model.lockRow.isOn }, set: { isOn in Task { await model.setLock(isOn) } })
    }
}
