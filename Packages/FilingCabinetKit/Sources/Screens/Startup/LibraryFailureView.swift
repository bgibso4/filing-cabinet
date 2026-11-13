import Core
import ScreenModels
import SwiftUI

/// Shown instead of the whole app when the library can't open (#40), in the welcome screens' layout: an icon well, the
/// New York title, the explanation, then Send report and Try again at the bottom. It never touches a file, and it
/// retries only when Try again is tapped.
public struct LibraryFailureView: View {
    private let model: LibraryFailureModel

    @Environment(\.dynamicTypeSize) private var typeSize
    /// The report Send report opens; `mailComposer` opens it and clears it.
    @State private var reportDraft: URL?

    // error-icon-v2.html, B1: a 64 pt well, 18 pt above the title, 10 pt above the explanation, 24 pt in from the sides.
    private static let wellSize: CGFloat = 64
    private static let titleGap: CGFloat = 18
    private static let messageGap: CGFloat = 10
    private static let sidePadding: CGFloat = 24
    // The well is the destructive colour at 12% (Plan 6 M4).
    private static let wellOpacity: Double = 0.12
    // design/prototype/index.html, the welcome's notifications step (.pagesheet, p, .go, .later): the content starts
    // 56 pt down, the explanation is at most 300 pt wide, the pill is 52 pt tall and the text button is 8 pt under it.
    private static let topPadding: CGFloat = 56
    private static let messageMaxWidth: CGFloat = 300
    private static let buttonHeight: CGFloat = 52
    private static let buttonGap: CGFloat = 8

    public init(model: LibraryFailureModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            message
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) { buttons }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Color.bgGrouped)
        .mailComposer(url: $reportDraft)
    }

    /// The icon, title and explanation.
    private var message: some View {
        VStack(spacing: 0) {
            // B1: a thin red X in a pale red circle. Title 2 follows Dynamic Type, and the well grows with it.
            SymbolWell(
                systemName: "xmark",
                font: Tokens.Typography.title2.weight(.light),
                foreground: Tokens.Color.destructive,
                fill: Tokens.Color.destructive.opacity(Self.wellOpacity),
                size: Self.wellSize)
            Text("Your library couldn’t open", bundle: #bundle)
                .font(Tokens.Typography.title1)
                .foregroundStyle(Tokens.Color.textPrimary)
                .padding(.top, Self.titleGap)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(AccessibilityID.LibraryFailure.title)
            Text(
                "Your scans are still on this iPhone and nothing was deleted. Send a report so it can be fixed, then try again.",
                bundle: #bundle
            )
            .font(Tokens.Typography.body)
            .foregroundStyle(Tokens.Color.textSecondary)
            // At accessibility sizes the 300 pt cap would leave a word or two per line.
            .frame(maxWidth: typeSize.isAccessibilitySize ? nil : Self.messageMaxWidth)
            .padding(.top, Self.messageGap)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Self.sidePadding)
        .padding(.top, Self.topPadding)
    }

    /// Send report, then Try again: fixed at the bottom while the explanation scrolls at large text.
    private var buttons: some View {
        VStack(spacing: Self.buttonGap) {
            // Opaque, as the welcome's pill (.go): the audit misreads Liquid Glass pills' contrast.
            CapsuleButton(
                identifier: AccessibilityID.LibraryFailure.sendReport, minHeight: Self.buttonHeight, action: sendReport
            ) {
                Text("Send report", bundle: #bundle)
            }
            TextButton(identifier: AccessibilityID.LibraryFailure.tryAgain, action: tryAgain) {
                Text("Try again", bundle: #bundle)
            }
        }
        .padding(.horizontal, Self.sidePadding)
        .padding(.bottom, Tokens.Spacing.s2)
        .background(Tokens.Color.bgGrouped)
    }

    private func sendReport() {
        model.reportOpened()
        reportDraft = model.reportURL
    }

    /// When the library still won't open, the screen stays and VoiceOver says so (M3).
    private func tryAgain() {
        model.tryAgain()
        if let announcement = model.announcement {
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
}
