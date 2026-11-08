import Core
import ScreenModels
import SwiftUI

/// A scan's details over the viewer (07-01 … 07-08, ScanDetails.dc.html lines 33-137): its title, which renames in
/// place, when it was scanned, its collection and its expiry. A compact sheet only as tall as its content; when the
/// text is larger than the screen allows, the content scrolls under the grabber. It draws its own grabber, so a
/// container only adds the sheet's surface and corners.
public struct DetailsSheet: View {
    private let model: DetailsModel
    /// The sheet's height, measured here; the viewer fits the page above it.
    @Binding private var height: CGFloat

    @State private var contentHeight: CGFloat?
    /// The title as typed while renaming.
    @State private var draft = ""
    @FocusState private var isTitleFocused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    // ScanDetails.dc.html line 34: 8 pt above the grabber, 16 pt either side and 18 pt below the content.
    private static let topPadding: CGFloat = 8
    private static let sidePadding: CGFloat = 16
    private static let bottomPadding: CGFloat = 18
    // ScanDetails.dc.html line 35: the grabber is 36 by 5 pt.
    private static let grabberWidth: CGFloat = 36
    private static let grabberHeight: CGFloat = 5
    // ScanDetails.dc.html line 39: the title row is 44 pt tall at least, 8 pt below the grabber and 4 pt in, the
    // pencil 8 pt after the title.
    private static let titleMinHeight: CGFloat = 44
    private static let titleTop: CGFloat = 8
    private static let textInset: CGFloat = 4
    // ScanDetails.dc.html line 54: renaming, the label starts 10 pt below the grabber.
    private static let editorTop: CGFloat = 10
    // The default-size sheet's height (07-01), shown for the instant before the real height is measured: 8 + 5 for the
    // grabber, 8 + 44 for the title, 18 for the scanned line, 14 + 121 for the rows (two 60 pt rows and a hairline) and
    // 18 below (ScanDetails.dc.html lines 34-97).
    private static let unmeasuredHeight: CGFloat = 236

    public init(model: DetailsModel, height: Binding<CGFloat>) {
        self.model = model
        _height = height
    }

    public var body: some View {
        VStack(spacing: 0) {
            grabber
            ScrollView {
                content.onGeometryChange(for: CGFloat.self, of: \.size.height) { contentHeight = $0 }
            }
            .frame(maxHeight: contentHeight)
            .scrollBounceBehavior(.basedOnSize)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Details.sheet)
        .onChange(of: contentHeight, initial: true) { height = sheetHeight }
        .onChange(of: model.isRenaming, initial: true) { _, isRenaming in
            if isRenaming { draft = model.title }
        }
        // Leaving the field commits, as Return does.
        .onChange(of: isTitleFocused) { _, isFocused in
            if !isFocused { commitTitle() }
        }
        .onDisappear(perform: commitTitle)
        .alert(
            model.editAlert?.title ?? "",
            isPresented: Binding(
                get: { model.editAlert != nil },
                set: { isPresented in
                    if !isPresented { model.dismissEditAlert() }
                }),
            presenting: model.editAlert
        ) { _ in
            Button(role: .cancel, action: model.dismissEditAlert) { Text("OK", bundle: #bundle) }
        } message: { alert in
            Text(alert.message)
        }
        .presentationDetents([.height(sheetHeight)])
        // The sheet draws the mock's grabber itself: the system one is an unidentified button.
        .presentationDragIndicator(.hidden)
        .presentationBackground(Tokens.Color.bgSurface)
        // The mocks don't dim the viewer: its back button still works with the sheet up.
        .presentationBackgroundInteraction(.enabled)
    }

    /// The sheet's full height, or a stand-in until the content is measured.
    private var sheetHeight: CGFloat {
        guard let contentHeight else { return Self.unmeasuredHeight }
        return Self.topPadding + Self.grabberHeight + contentHeight
    }

    private var grabber: some View {
        Capsule()
            .fill(Tokens.Color.chevron)
            .frame(width: Self.grabberWidth, height: Self.grabberHeight)
            .padding(.top, Self.topPadding)
            .accessibilityHidden(true)
    }

    /// While renaming only the field shows (07-03).
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isRenaming {
                DetailsTitleEditor(text: $draft, isFocused: $isTitleFocused, onCommit: commitTitle)
                    .padding(.top, Self.editorTop)
            } else {
                titleButton
                    .padding(.top, Self.titleTop)
                    .padding(.horizontal, Self.textInset)
                Text(model.scannedLine)
                    .font(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(AccessibilityID.Details.scannedLine)
                    .padding(.horizontal, Self.textInset)
                DetailsRows(model: model)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Self.sidePadding)
        .padding(.bottom, Self.bottomPadding)
    }

    /// The serif title with its pencil: tapping it renames.
    private var titleButton: some View {
        Button(action: startRenaming) {
            // The pencil stays with the title's first line when it wraps.
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.s2) {
                Text(model.title)
                    // Title 2 is the closest token to the mock's 24 pt.
                    .font(Tokens.Typography.title2)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    // ScanDetails.dc.html line 41: one line with an ellipsis; above the default size it wraps.
                    .lineLimit(typeSize <= .large ? 1 : nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(AccessibilityID.Details.titleText)
                Image(systemName: "pencil")
                    // Body is the mock's 17 pt glyph.
                    .font(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: Self.titleMinHeight, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Rename \(model.title)", bundle: #bundle))
        .accessibilityIdentifier(AccessibilityID.Details.title)
    }

    private func startRenaming() {
        model.startRenaming()
        isTitleFocused = true
    }

    /// Return, leaving the field or closing the sheet: the typed title is kept (a blank one keeps the old title).
    private func commitTitle() {
        guard model.isRenaming else { return }
        model.rename(draft)
        isTitleFocused = false
    }
}
