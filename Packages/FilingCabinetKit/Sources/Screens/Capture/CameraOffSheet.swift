import Core
import SwiftUI
import UIKit

/// Shown on every Scan after the user turned camera access off: iOS won't ask again, so it points to Settings.
/// A compact sheet that hugs its content (04-01, 04-04). When the text is larger than the sheet can be, it scrolls
/// between a header (the grabber and Close) and Open Settings, both of which stay put. It draws its own grabber, so a
/// container only adds the sheet's surface and corners.
public struct CameraOffSheet: View {
    private let onOpenSettings: () -> Void
    private let onClose: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The heights the sheet hugs, measured because the text's height depends on its size and the screen's width.
    /// Nil until measured: the scroll view is unconstrained and the detent is `unmeasuredHeight` until then.
    @State private var messageHeight: CGFloat?
    @State private var buttonHeight: CGFloat?
    /// The Close circle's height without its inset, which grows with Dynamic Type; 0 until measured.
    @State private var closeCircleHeight: CGFloat = 0

    // Home.dc.html line 288: 20 pt side and bottom padding; the content starts 30 pt below the 5 pt grabber,
    // which sits 8 pt from the top.
    private static let sidePadding: CGFloat = 20
    private static let topPadding: CGFloat = 43
    // About the default-size sheet's height (the mock's 04-01), shown for the instant before the real height is measured.
    private static let unmeasuredHeight: CGFloat = 330
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
            header
                // Above the scroll view, so the part of Close's target that reaches into it still takes taps.
                .zIndex(1)
            ScrollView {
                message.onGeometryChange(for: CGFloat.self, of: \.size.height) { messageHeight = $0 }
            }
            .frame(maxHeight: messageHeight)
            openSettingsButton
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { buttonHeight = $0 }
        }
        // Ben's decision (2026-11-06): the mocks' compact sheet. On iOS 27 any detent shorter than .large makes a floating
        // sheet, and the accessibility audit reports its text as clipped even when it is intact, so this sheet's text has
        // a textClipped exemption in UITests/Support/Audit.swift. Every other audit type still applies to it.
        .presentationDetents([.height(detentHeight)])
        // The sheet draws the mock's grabber itself: the system one is an unidentified button, and Close already
        // dismisses for VoiceOver.
        .presentationDragIndicator(.hidden)
        .presentationBackground(Tokens.Color.bgSurface)
    }

    /// The sheet's full height, or a stand-in until everything is measured.
    private var detentHeight: CGFloat {
        guard let messageHeight, let buttonHeight else { return Self.unmeasuredHeight }
        return headerHeight + messageHeight + buttonHeight
    }

    /// The mock's top padding at default sizes, where Close's circle reaches 11 pt past it into empty space. Once Close
    /// scales up, the header holds the whole circle, so scrolled text never passes under it.
    private var headerHeight: CGFloat {
        closeCircleHeight > Self.closeSize ? Self.closeInset + closeCircleHeight : Self.topPadding
    }

    /// The grabber and Close: not part of the scrolling content.
    private var header: some View {
        ZStack(alignment: .topTrailing) {
            grabber.frame(maxWidth: .infinity, alignment: .top)
            closeButton
        }
        .frame(height: headerHeight, alignment: .top)
    }

    /// The icon, title and explanation.
    private var message: some View {
        VStack(spacing: 0) {
            // Large title is the mock's 34 pt glyph, and it follows Dynamic Type; the well grows with it.
            SymbolWell(
                systemName: "video.slash",
                font: Tokens.Typography.largeTitle.weight(.regular),
                foreground: Tokens.Color.textSecondary,
                fill: Tokens.Color.bgWell,
                size: Self.wellSize)
            Text("Camera access is off", bundle: #bundle)
                .font(Tokens.Typography.title1)
                .foregroundStyle(Tokens.Color.textPrimary)
                .padding(.top, Self.titleGap)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(AccessibilityID.CameraOff.title)
            Text(
                "Filing Cabinet needs the camera to scan documents. Tap Open Settings, turn on Camera, then come back.",
                bundle: #bundle
            )
            .font(Tokens.Typography.body)
            .foregroundStyle(Tokens.Color.textSecondary)
            // At accessibility sizes the mock's 300 pt cap would leave a word or two per line.
            .frame(maxWidth: typeSize.isAccessibilitySize ? nil : Self.messageMaxWidth)
            .padding(.top, Self.messageGap)
            .accessibilityIdentifier(AccessibilityID.CameraOff.message)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Self.sidePadding)
    }

    private var openSettingsButton: some View {
        CapsuleButton(
            identifier: AccessibilityID.CameraOff.openSettings, minHeight: Self.buttonMinHeight, action: openSettings
        ) {
            Text("Open Settings", bundle: #bundle)
        }
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
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { closeCircleHeight = $0 }
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
