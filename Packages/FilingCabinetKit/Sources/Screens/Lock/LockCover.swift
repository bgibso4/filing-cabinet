import Core
import SwiftUI

/// The lock cover (library-lock mocks, Mock 1): the app's mark, its name and "Locked" on Home's ground, and only after
/// Face ID was cancelled or failed, Unlock. One modal container, so VoiceOver reaches nothing under it. The shield shows
/// it above every window; RootView shows it without the button over the library, under a Scan request's capture layer.
public struct LockCover: View {
    private let showsUnlock: Bool
    private let onUnlock: () -> Void

    // Mock 1 (.cover img): the mark is 76 pt, in the icon's own continuous corners, 18 pt.
    private static let markSize: CGFloat = 76
    private static let markRadius: CGFloat = 18
    // Mock 1 (.cover .stack, .name, .sub, .unlock): 10 pt between items, 6 more above the name, 4 fewer above "Locked",
    // 18 more above Unlock.
    private static let nameGap: CGFloat = 16
    private static let lockedGap: CGFloat = 6
    private static let unlockGap: CGFloat = 28
    // Mock 1 (.cover): 28 pt in from the sides, centred over a 40 pt bottom inset, so it sits a little above the middle.
    private static let sidePadding: CGFloat = 28
    private static let bottomPadding: CGFloat = 40

    public init(showsUnlock: Bool, onUnlock: @escaping () -> Void) {
        self.showsUnlock = showsUnlock
        self.onUnlock = onUnlock
    }

    public var body: some View {
        VStack(spacing: 0) {
            Image("app-mark", bundle: #bundle)
                .resizable()
                .frame(width: Self.markSize, height: Self.markSize)
                .clipShape(.rect(cornerRadius: Self.markRadius, style: .continuous))
                .accessibilityHidden(true)
            VStack(spacing: Self.lockedGap) {
                Text("Filing Cabinet", bundle: #bundle)
                    .font(Tokens.Typography.title1)
                    .foregroundStyle(Tokens.Color.textPrimary)
                Text("Locked", bundle: #bundle)
                    .font(Tokens.Typography.subheadline)
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
            .padding(.top, Self.nameGap)
            // "Filing Cabinet, Locked".
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            if showsUnlock {
                // As wide as its label (.unlock is inline), at least 44 pt tall.
                CapsuleButton(
                    identifier: AccessibilityID.Lock.unlock, minHeight: Tokens.Spacing.tapMin, action: onUnlock
                ) {
                    Label {
                        Text("Unlock", bundle: #bundle)
                    } icon: {
                        Image(systemName: "faceid")
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.top, Self.unlockGap)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Self.sidePadding)
        .padding(.bottom, Self.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Color.bgGrouped)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier(AccessibilityID.Lock.cover)
    }
}
