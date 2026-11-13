import Core
import Library
import ScreenModels
import SwiftUI

/// One of Search's results (08-03): the thumbnail, the title, the matching line with every match in bold, then the
/// collection's dot, name and day, and a chevron. One VoiceOver element, read as one sentence.
struct SearchResultRow: View {
    let result: SearchResult
    let showsSeparator: Bool
    let thumbnails: any ThumbnailProviding
    let onOpen: () -> Void

    // Search.dc.html line 91: a 44 × 58 pt thumbnail with a 0.5 pt edge, 12 pt from the text.
    private static let thumbnailSize = CGSize(width: 44, height: 58)
    private static let thumbnailEdge: CGFloat = 0.5
    // Search.dc.html line 92: 12 pt above and below the text.
    private static let textPadding = Tokens.Spacing.s3
    // Search.dc.html line 96: 5 pt from the dot to the collection's name.
    private static let dotGap: CGFloat = 5

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: onOpen) {
            Group {
                if typeSize.isAccessibilitySize { stacked } else { inline }
            }
            .padding(.horizontal, Tokens.Spacing.s4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(result.accessibilityLabel)
        .accessibilityIdentifier(AccessibilityID.Search.result(result.id))
    }

    /// Thumbnail, texts and chevron on one line, with the separator inset to the text (Search.dc.html line 89).
    private var inline: some View {
        HStack(spacing: Tokens.Spacing.s3) {
            thumbnail
            HStack(spacing: Tokens.Spacing.s3) {
                texts
                Spacer(minLength: 0)
                DisclosureChevron()
            }
            .padding(.vertical, Self.textPadding)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .top) { separator }
        }
    }

    /// At accessibility sizes the texts get the full width under the thumbnail and chevron, as Home's rows do, and
    /// the separator spans the row.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s2) {
            HStack(spacing: Tokens.Spacing.s3) {
                thumbnail
                Spacer(minLength: 0)
                DisclosureChevron()
            }
            texts
        }
        .padding(.vertical, Self.textPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { separator }
    }

    @ViewBuilder
    private var separator: some View {
        if showsSeparator { Hairline() }
    }

    private var thumbnail: some View {
        ThumbnailView(id: result.id, page: 0, provider: thumbnails, showsWideImagesWhole: true)
            .frame(width: Self.thumbnailSize.width, height: Self.thumbnailSize.height)
            .clipShape(.rect(cornerRadius: Tokens.Radius.nested))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.nested)
                    .strokeBorder(Tokens.Color.separator, lineWidth: Self.thumbnailEdge)
            }
    }

    private var texts: some View {
        // Search.dc.html lines 94-95: one line each with an ellipsis; above the default size they wrap rather than
        // cutting off (requirements 06 · Accessibility).
        let lineLimit = typeSize <= .large ? 1 : nil
        return VStack(alignment: .leading, spacing: 0) {
            Text(result.title)
                .font(Tokens.Typography.body)
                .foregroundStyle(Tokens.Color.textPrimary)
                .lineLimit(lineLimit)
            secondLine(lineLimit: lineLimit)
            // At large text the line wraps, and the dot stays with its first line (as the viewer's header).
            HStack(alignment: typeSize.isAccessibilitySize ? .firstTextBaseline : .center, spacing: Self.dotGap) {
                CollectionDot(collection: result.collection)
                Text(result.detail)
                    .font(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func secondLine(lineLimit: Int?) -> some View {
        switch result.secondLine {
        case .snippet(let line, let bold):
            Text(snippet(line, bold: bold))
                .font(Tokens.Typography.subheadline)
                .foregroundStyle(Tokens.Color.textSecondary)
                .lineLimit(lineLimit)
        case .hiddenWord(let query):
            // The scan has no such word on it: a sparkle and what the model's hidden word matched (M8).
            HStack(alignment: .firstTextBaseline, spacing: Self.dotGap) {
                Image(systemName: "sparkles")
                    .accessibilityHidden(true)
                Text(matches(query))
                    .lineLimit(lineLimit)
            }
            .font(Tokens.Typography.subheadline)
            .foregroundStyle(Tokens.Color.textSecondary)
        }
    }

    /// The matching line, each match semibold in the primary colour (Search.dc.html line 95).
    private func snippet(_ line: String, bold: [Range<String.Index>]) -> AttributedString {
        var text = AttributedString(line)
        for match in bold {
            guard let range = Range(match, in: text) else { continue }
            text[range].font = Tokens.Typography.subheadline.weight(.semibold)
            text[range].foregroundColor = Tokens.Color.textPrimary
        }
        return text
    }

    /// "Matches ID", the query semibold in the primary colour, as a snippet's matches are.
    private func matches(_ query: String) -> AttributedString {
        var text = AttributedString(SearchResult.matchesLine(query))
        if let range = text.range(of: query, options: .backwards) {
            text[range].font = Tokens.Typography.subheadline.weight(.semibold)
            text[range].foregroundColor = Tokens.Color.textPrimary
        }
        return text
    }
}
