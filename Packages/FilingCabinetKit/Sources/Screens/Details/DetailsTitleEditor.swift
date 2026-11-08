import Core
import SwiftUI

/// The title as a field (07-03, ScanDetails.dc.html lines 54-63): "Title", the field with its clear button, and where
/// the title came from. Return, or leaving the field, commits.
struct DetailsTitleEditor: View {
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding
    let onCommit: () -> Void

    // ScanDetails.dc.html line 56: the field is 50 pt tall and 14 pt in before the text (the clear button's 44 pt
    // target makes up the mock's 8 pt after it), with a 1.5 pt edge while it is edited; the label, field and hint are
    // 6 pt apart and the labels 4 pt in.
    private static let fieldHeight: CGFloat = 50
    private static let fieldLeading: CGFloat = 14
    private static let edgeWidth: CGFloat = 1.5
    private static let gap: CGFloat = 6
    private static let labelInset: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            Text("Title", bundle: #bundle)
                .font(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Color.textSecondary)
                .padding(.horizontal, Self.labelInset)
                .accessibilityHidden(true)
            field
            Text("Suggested from the scan’s text. Search finds it by title and text.", bundle: #bundle)
                .font(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Self.labelInset)
        }
    }

    private var field: some View {
        HStack(spacing: Tokens.Spacing.s2) {
            // Vertical, so a long title or large text wraps rather than cutting off, as Review's title field does.
            TextField(text: typedText, axis: .vertical) {
                Text("Title", bundle: #bundle)
            }
            // Headline is the closest token to the mock's 20 pt semibold.
            .font(Tokens.Typography.headline)
            .foregroundStyle(Tokens.Color.textPrimary)
            .focused(isFocused)
            .submitLabel(.done)
            .accessibilityIdentifier(AccessibilityID.Details.titleField)
            // Wrapped lines keep off the field's edge.
            .padding(.vertical, Tokens.Spacing.s2)
            if !text.isEmpty { clearButton }
        }
        .padding(.leading, Self.fieldLeading)
        .frame(minHeight: Self.fieldHeight)
        .background(Tokens.Color.bgWell, in: .rect(cornerRadius: Tokens.Radius.surface))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.surface)
                .strokeBorder(Tokens.Color.textPrimary, lineWidth: Self.edgeWidth)
        }
    }

    /// The title as typed. A vertical field takes Return as a new line, so a line break commits instead.
    private var typedText: Binding<String> {
        Binding(
            get: { text },
            set: { typed in
                if typed.contains(where: \.isNewline) {
                    text = typed.filter { !$0.isNewline }
                    onCommit()
                } else {
                    text = typed
                }
            })
    }

    private var clearButton: some View {
        Button {
            text = ""
        } label: {
            Image(systemName: "xmark.circle.fill")
                // Body is the mock's 18 pt glyph.
                .font(Tokens.Typography.body)
                .foregroundStyle(Tokens.Color.textTertiary)
                .frame(minWidth: Tokens.Spacing.tapMin, minHeight: Tokens.Spacing.tapMin)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Clear", bundle: #bundle))
        .accessibilityIdentifier(AccessibilityID.Details.clearTitle)
    }
}
