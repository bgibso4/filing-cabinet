import Core
import ScreenModels
import SwiftUI

/// Review's sheet (Review.dc.html lines 282-311): the editable title, the Collection and Expiry rows, and a
/// full-width Save. When it is taller than the room it gets, the title and rows scroll and Save stays below them.
struct ReviewSheet: View {
    let model: ReviewModel
    let onSave: () -> Void

    @FocusState private var isEditingTitle: Bool

    // Review.dc.html line 284: the sheet is 8 pt in from the screen's sides and bottom, with 8 pt above the grabber.
    private static let inset: CGFloat = 8
    private static let topPadding: CGFloat = 8
    // Review.dc.html line 285: the grabber is 36 by 5 pt.
    private static let grabberWidth: CGFloat = 36
    private static let grabberHeight: CGFloat = 5
    // Review.dc.html line 286: the title row is 44 pt tall at least, 6 pt below the grabber and 4 pt in.
    private static let titleMinHeight: CGFloat = 44
    private static let titleTop: CGFloat = 6
    private static let titleInset: CGFloat = 4
    // Review.dc.html line 290: the rows start 10 pt below the title.
    private static let rowsTop: CGFloat = 10
    // Review.dc.html line 309: Save is 54 pt tall at least, 14 pt below the rows.
    private static let saveMinHeight: CGFloat = 54
    private static let saveTop: CGFloat = 14

    var body: some View {
        VStack(spacing: 0) {
            grabber
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    title
                        .padding(.top, Self.titleTop)
                        .padding(.horizontal, Self.titleInset)
                    rows
                        .padding(.top, Self.rowsTop)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            saveButton
                .padding(.top, Self.saveTop)
        }
        .padding(.top, Self.topPadding)
        .padding([.horizontal, .bottom], Tokens.Spacing.s4)
        .background(Tokens.Color.bgSurface, in: Self.shape)
        .padding(Self.inset)
        // Only the user's pick: a suggestion filling the collection has its own haptic (ReviewView).
        .sensoryFeedback(.selection, trigger: model.collection) { _, _ in model.isCollectionPicked }
        .sensoryFeedback(.selection, trigger: model.expiryOverride)
    }

    /// Concentric with the screen's corners, never tighter than a surface.
    private static let shape = ConcentricRectangle(
        corners: .concentric(minimum: .fixed(Tokens.Radius.surface)), isUniform: true)

    /// Decoration from the mock: this sheet doesn't move.
    private var grabber: some View {
        Capsule()
            .fill(Tokens.Color.chevron)
            .frame(width: Self.grabberWidth, height: Self.grabberHeight)
            .accessibilityHidden(true)
    }

    // MARK: Title

    /// The serif title, editable in place, with the pencil right after it. Return ends editing.
    private var title: some View {
        HStack(spacing: Tokens.Spacing.s2) {
            // The field takes all the width it is offered, so a hidden copy of the text sizes it: the pencil follows
            // a short title, and a long one wraps. Hidden views are not in the accessibility tree.
            Text(model.title.isEmpty ? model.fallbackTitle : model.title)
                .font(Tokens.Typography.title2)
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .overlay(alignment: .leading) { titleField }
            Image(systemName: "pencil")
                // Body is the mock's 17 pt glyph.
                .font(Tokens.Typography.body)
                .foregroundStyle(Tokens.Color.textSecondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: Self.titleMinHeight, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture { isEditingTitle = true }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Review.title)
    }

    private var titleField: some View {
        TextField(text: titleText, prompt: Text(model.fallbackTitle), axis: .vertical) {
            Text("Title", bundle: #bundle)
        }
        .font(Tokens.Typography.title2)
        .foregroundStyle(Tokens.Color.textPrimary)
        .focused($isEditingTitle)
        // The save has already taken the title.
        .disabled(model.isSaving)
        .submitLabel(.done)
        .accessibilityIdentifier(AccessibilityID.Review.titleField)
    }

    /// The title as typed. A vertical field takes Return as a new line, so a line break ends editing instead.
    private var titleText: Binding<String> {
        Binding(
            get: { model.title },
            set: { text in
                if text.contains(where: \.isNewline) {
                    model.editTitle(text.filter { !$0.isNewline })
                    isEditingTitle = false
                } else {
                    model.editTitle(text)
                }
            })
    }

    // MARK: Rows

    private var rows: some View {
        VStack(spacing: 0) {
            CollectionMenu(
                label: model.collectionLabel,
                value: model.collectionValue,
                collection: model.collection,
                options: model.collectionOptions,
                identifier: AccessibilityID.Review.collection,
                choose: model.choose)
            Hairline()
            ExpiryMenu(model: model, identifier: AccessibilityID.Review.expiry)
                // Off, with secondary text, until a collection is chosen.
                .disabled(!model.isExpiryEnabled)
        }
        // The save has already taken the choices.
        .disabled(model.isSaving)
        .background(Tokens.Color.bgWell, in: .rect(cornerRadius: Tokens.Radius.surface))
    }

    // MARK: Save

    private var saveButton: some View {
        Button(action: onSave) {
            Text(model.saveTitle)
                .font(Tokens.Typography.headline)
                .foregroundStyle(model.canSave ? Tokens.Color.bgGrouped : Tokens.Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Tokens.Spacing.s6)
                .padding(.vertical, Tokens.Spacing.s2)
                .frame(maxWidth: .infinity, minHeight: Self.saveMinHeight)
                .background(model.canSave ? Tokens.Color.tint : Tokens.Color.bgWell, in: .capsule)
        }
        // Not .plain, which fades a disabled label below the mock's colours (and below AA contrast).
        .buttonStyle(UnfadedButtonStyle())
        .disabled(!model.canSave)
        .accessibilityIdentifier(AccessibilityID.Review.save)
    }
}
