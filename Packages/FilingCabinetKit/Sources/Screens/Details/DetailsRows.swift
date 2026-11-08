import Core
import ScreenModels
import SwiftUI

/// The well with the Collection and Expiry rows (ScanDetails.dc.html lines 73-97), each opening its menu, and after a
/// move the note under it with Undo (lines 133-136).
struct DetailsRows: View {
    let model: DetailsModel

    // ScanDetails.dc.html line 73: the well starts 14 pt below the scanned line.
    private static let wellTop: CGFloat = 14
    // ScanDetails.dc.html line 135: the note is 10 pt below the well and 4 pt in, 12 pt before its Undo (Undo keeps a
    // 44 pt target rather than the mock's 32).
    private static let noteTop: CGFloat = 10
    private static let noteInset: CGFloat = 4
    private static let noteGap: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            well
                .padding(.top, Self.wellTop)
            if let note = model.movedNote {
                movedNote(note)
                    .padding(.top, Self.noteTop)
                    .padding(.horizontal, Self.noteInset)
            }
        }
        .sensoryFeedback(.selection, trigger: model.collection)
    }

    private var well: some View {
        VStack(spacing: 0) {
            CollectionMenu(
                label: String(localized: "Collection", bundle: #bundle),
                value: model.collectionName,
                collection: model.collection,
                options: model.collectionOptions,
                identifier: AccessibilityID.Details.collection,
                choose: model.choose)
            Hairline()
            ExpiryMenu(model: model, identifier: AccessibilityID.Details.expiry, isSoon: model.isExpirySoon)
        }
        .background(Tokens.Color.bgWell, in: .rect(cornerRadius: Tokens.Radius.surface))
    }

    /// "Expiry now follows Documents." and Undo.
    private func movedNote(_ note: MovedNote) -> some View {
        HStack(spacing: Self.noteGap) {
            Text(note.text)
                .font(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: model.undoMove) {
                Text("Undo", bundle: #bundle)
                    .font(Tokens.Typography.footnote.weight(.semibold))
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .frame(minHeight: Tokens.Spacing.tapMin)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.Details.undo)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
