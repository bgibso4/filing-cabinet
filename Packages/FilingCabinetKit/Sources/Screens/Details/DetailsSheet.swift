import Core
import ScreenModels
import SwiftUI

/// A scan's details over the viewer (07-01 … 07-08, ScanDetails.dc.html lines 33-137): its title, which renames in
/// place, when it was scanned, its collection and its expiry. Only as tall as its content; when the text is larger
/// than the screen allows, the content scrolls, cut off at the body's top edge just under the grabber. It draws its own
/// grabber, and `DetailsPanel` adds the surface, corners and motion.
///
/// The grabber always drags the panel. The body scrolls first, as Apple's sheets do: a drag on it moves the panel only
/// downward from its top (`DetailsMotion.bodyDragMovesPanel`). Neither drags while renaming, where it would fight the
/// field's own.
struct DetailsSheet: View {
    private let model: DetailsModel
    private let onDrag: (DetailsDrag) -> Void
    /// The title field's focus, owned by `DetailsPanel`, which ends renaming on a tap outside the panel too.
    private let isTitleFocused: FocusState<Bool>.Binding

    @State private var contentHeight: CGFloat?
    /// Whether the body is scrolled to its top (or pulled past it); written only when that changes.
    @State private var isBodyAtTop = true
    /// The title as typed while renaming.
    @State private var draft = ""
    @Environment(\.dynamicTypeSize) private var typeSize

    // ScanDetails.dc.html line 34: 16 pt either side and 18 pt below the content.
    private static let sidePadding: CGFloat = 16
    private static let bottomPadding: CGFloat = 18
    // ScanDetails.dc.html line 39: the title row is 44 pt tall at least, 8 pt below the grabber and 4 pt in, the
    // pencil 8 pt after the title.
    private static let titleMinHeight: CGFloat = 44
    private static let titleTop: CGFloat = 8
    private static let textInset: CGFloat = 4
    // ScanDetails.dc.html line 54: renaming, the label starts 10 pt below the grabber.
    private static let editorTop: CGFloat = 10

    init(model: DetailsModel, isTitleFocused: FocusState<Bool>.Binding, onDrag: @escaping (DetailsDrag) -> Void) {
        self.model = model
        self.isTitleFocused = isTitleFocused
        self.onDrag = onDrag
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailsGrabber(isEnabled: !model.isRenaming, onDrag: onDrag)
            ScrollView {
                content.onGeometryChange(for: CGFloat.self, of: \.size.height) { contentHeight = $0 }
            }
            .frame(maxHeight: contentHeight)
            .scrollBounceBehavior(.basedOnSize)
            // Renaming at a large text size, the body scrolls, and a drag down on it takes the keyboard away.
            .scrollDismissesKeyboard(.interactively)
            .onScrollGeometryChange(
                for: Bool.self,
                of: { DetailsMotion.bodyIsAtTop(scrolled: $0.contentOffset.y + $0.contentInsets.top) },
                action: { isBodyAtTop = $1 }
            )
            .gesture(
                DetailsSwipe(
                    begins: {
                        !model.isRenaming
                            && DetailsMotion.bodyDragMovesPanel(translation: $0, isBodyAtTop: isBodyAtTop)
                    },
                    onDrag: onDrag))
        }
        .onChange(of: model.isRenaming, initial: true) { _, isRenaming in
            if isRenaming { draft = model.title }
        }
        // Leaving the field commits, as Return does.
        .onChange(of: isTitleFocused.wrappedValue) { _, isFocused in
            if !isFocused { commitTitle() }
        }
        .onDisappear(perform: commitTitle)
        .editAlert(model.editAlert, dismiss: model.dismissEditAlert)
        // A move that would send the scan to Trash asks first (07-07); Move closes the sheet as the viewer pops.
        .alert(
            model.pendingTrashMove?.title ?? "",
            isPresented: Binding(
                get: { model.pendingTrashMove != nil },
                set: { isPresented in
                    if !isPresented { model.cancelTrashMove() }
                }),
            presenting: model.pendingTrashMove
        ) { _ in
            Button(role: .cancel, action: model.cancelTrashMove) { Text("Cancel", bundle: #bundle) }
            Button(action: confirmTrashMove) { Text("Move", bundle: #bundle) }
        } message: { alert in
            Text(alert.message)
        }
    }

    /// While renaming only the field shows (07-03).
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isRenaming {
                DetailsTitleEditor(text: $draft, isFocused: isTitleFocused, onCommit: commitTitle)
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

    private func confirmTrashMove() {
        model.confirmTrashMove()
        if model.isMissing { MovedToTrash.announce() }
    }

    private func startRenaming() {
        model.startRenaming()
        isTitleFocused.wrappedValue = true
    }

    /// Return, leaving the field or closing the sheet: the typed title is kept (a blank one keeps the old title).
    private func commitTitle() {
        guard model.isRenaming else { return }
        model.rename(draft)
        isTitleFocused.wrappedValue = false
    }
}
