import Core
import SwiftUI
import UIKit

/// Shown on every Scan after the user turned camera access off: iOS won't ask again, so it points to Settings.
/// A full-height sheet: the text scrolls, with Open Settings pinned below it. It draws its own grabber, so a container
/// only adds the sheet's surface and corners.
public struct CameraOffSheet: View {
    private let onOpenSettings: () -> Void
    private let onClose: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize

    // Home.dc.html line 288: 20 pt side and bottom padding; the content starts 30 pt below the 5 pt grabber,
    // which sits 8 pt from the top.
    private static let sidePadding: CGFloat = 20
    private static let topPadding: CGFloat = 43
    // Home.dc.html line 289: the grabber is 36 by 5 pt.
    private static let grabberWidth: CGFloat = 36
    private static let grabberHeight: CGFloat = 5
    private static let grabberTop: CGFloat = 8
    // Home.dc.html line 290: the close button is 40 pt (at default sizes), 14 pt in from the top and trailing edges.
    private static let closeSize: CGFloat = 40
    private static let closeInset: CGFloat = 14
    // Home.dc.html line 291: a 72 pt well (at default sizes) with a 34 pt symbol.
    private static let wellSize: CGFloat = 72
    // Home.dc.html lines 292-294: 18 pt above the title, 8 pt above the text (at most 300 pt wide), 24 pt above
    // the 54 pt button.
    private static let titleGap: CGFloat = 18
    private static let messageGap: CGFloat = 8
    private static let messageMaxWidth: CGFloat = 300
    private static let buttonGap: CGFloat = 24
    private static let buttonMinHeight: CGFloat = 54

    public init(onOpenSettings: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        self.onClose = onClose
    }

    public var body: some View {
        // One copy of the content: ViewThatFits would keep a hidden second copy that the accessibility audit reports.
        VStack(spacing: 0) {
            ScrollView { message }
            openSettingsButton
                .fixedSize(horizontal: false, vertical: true)
        }
        .overlay(alignment: .top) { grabber }
        .overlay(alignment: .topTrailing) { closeButton }
        // Departs from 04-01/04-04, whose sheet hugs its content: on iOS 27 any shorter detent (a measured height, or
        // .medium) makes a floating sheet, and the accessibility audit reports its text as clipped even when it isn't.
        // A full-height sheet passes. Ruling, Task 13.
        .presentationDetents([.large])
        // The sheet draws the mock's grabber itself: the system one is an unidentified button, and Close already
        // dismisses for VoiceOver.
        .presentationDragIndicator(.hidden)
        .presentationBackground(Tokens.Color.bgSurface)
    }

    /// The icon, title and explanation.
    private var message: some View {
        VStack(spacing: 0) {
            // Large title is the mock's 34 pt glyph, and it follows Dynamic Type; the well grows with it.
            Image(systemName: "video.slash")
                .font(Tokens.Typography.largeTitle.weight(.regular))
                .foregroundStyle(Tokens.Color.textSecondary)
                .padding(Tokens.Spacing.s3)
                .frame(minWidth: Self.wellSize, minHeight: Self.wellSize)
                .background(Tokens.Color.bgWell, in: .circle)
                .accessibilityHidden(true)
            Text("Camera access is off", bundle: #bundle)
                .font(Tokens.Typography.title1)
                .foregroundStyle(Tokens.Color.textPrimary)
                .padding(.top, Self.titleGap)
                .accessibilityAddTraits(.isHeader)
            Text(
                "Filing Cabinet needs the camera to scan documents. Tap Open Settings, turn on Camera, then come back.",
                bundle: #bundle
            )
            .font(Tokens.Typography.body)
            .foregroundStyle(Tokens.Color.textSecondary)
            // At accessibility sizes the mock's 300 pt cap would leave a word or two per line.
            .frame(maxWidth: typeSize.isAccessibilitySize ? nil : Self.messageMaxWidth)
            .padding(.top, Self.messageGap)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Self.sidePadding)
        .padding(.top, Self.topPadding)
    }

    private var openSettingsButton: some View {
        Button(action: openSettings) {
            Text("Open Settings", bundle: #bundle)
                .font(Tokens.Typography.headline)
                .foregroundStyle(Tokens.Color.bgGrouped)
                .multilineTextAlignment(.center)
                // Wraps rather than truncates when the text is large.
                .fixedSize(horizontal: false, vertical: true)
                // Keeps large text off the capsule's ends; at default sizes the pill is wider than the label anyway.
                .padding(.horizontal, Tokens.Spacing.s6)
                .padding(.vertical, Tokens.Spacing.s2)
                .frame(maxWidth: .infinity, minHeight: Self.buttonMinHeight)
                .background(Tokens.Color.tint, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.CameraOff.openSettings)
        .padding(.top, Self.buttonGap)
        .padding([.horizontal, .bottom], Self.sidePadding)
    }

    private var grabber: some View {
        Capsule()
            .fill(Tokens.Color.chevron)
            .frame(width: Self.grabberWidth, height: Self.grabberHeight)
            .padding(.top, Self.grabberTop)
            .accessibilityHidden(true)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            // Footnote is the mock's 13 pt glyph, and it follows Dynamic Type; the circle grows with it.
            Image(systemName: "xmark")
                .font(Tokens.Typography.footnote.weight(.bold))
                .foregroundStyle(Tokens.Color.textSecondary)
                .padding(Tokens.Spacing.s3)
                .frame(minWidth: Self.closeSize, minHeight: Self.closeSize)
                .background(Tokens.Color.bgWell, in: .circle)
                // The 40 pt circle from the mock, with a 44 pt target.
                .frame(minWidth: Tokens.Spacing.tapMin, minHeight: Tokens.Spacing.tapMin)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Close", bundle: #bundle))
        .accessibilityIdentifier(AccessibilityID.CameraOff.close)
        .padding(Self.closeInset - (Tokens.Spacing.tapMin - Self.closeSize) / 2)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
        onOpenSettings()
    }
}

#Preview("Light") {
    Color.clear.sheet(isPresented: .constant(true)) { CameraOffSheet(onOpenSettings: {}, onClose: {}) }
}

#Preview("Dark") {
    Color.clear.sheet(isPresented: .constant(true)) { CameraOffSheet(onOpenSettings: {}, onClose: {}) }
        .preferredColorScheme(.dark)
}
