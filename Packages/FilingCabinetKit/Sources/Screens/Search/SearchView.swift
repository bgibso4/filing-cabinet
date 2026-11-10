import Core
import Library
import ScreenModels
import SwiftUI

/// Search, pushed from Home's field (M14, E1): its own field at the top, focused on arrival, and an X back to Home;
/// the filters under it; then what `SearchModel` says to show (08-01…08-06). No Scan. A result opens the viewer on
/// the same stack, and back returns here with the query and results kept.
public struct SearchView: View {
    @Bindable private var model: SearchModel
    private let thumbnails: any ThumbnailProviding
    private let focusesOnArrival: Bool
    private let onOpen: (ScanID) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var isFocused: Bool
    /// Set on the first appearance: coming back from the viewer leaves the keyboard down.
    @State private var hasArrived = false

    // Search.dc.html line 21: the field is 44 pt, 16 pt in on the left and 6 pt on the right, its glyph 8 pt from the
    // text, and 10 pt from the X (line 31), a 44 pt circle.
    private static let fieldMinHeight = Tokens.Spacing.tapMin
    private static let fieldLeading = Tokens.Spacing.s4
    private static let fieldTrailing: CGFloat = 6
    private static let fieldGap: CGFloat = 10
    private static let closeDiameter = Tokens.Spacing.tapMin
    // My call (no large-text mock): the field grows to three lines at most.
    private static let fieldLines = 3
    // Search.dc.html line 28: the field's clear button is 32 pt.
    private static let clearQuerySize: CGFloat = 32
    // Search.dc.html line 46: the filters sit 10 pt under the field.
    private static let chipsTopGap: CGFloat = 10
    // Search.dc.html line 82: the result count sits 18 pt under the filters and 8 pt over the card.
    private static let countTopGap: CGFloat = 18
    private static let countBottomGap = Tokens.Spacing.s2
    // Search.dc.html line 155: the empty states' lines are 8 pt apart, 24 pt in, the body at most 290 pt wide, and
    // "Search all scans" 10 pt further down, 20 pt in.
    private static let emptyGap = Tokens.Spacing.s2
    private static let emptyBodyMaxWidth: CGFloat = 290
    private static let searchAllTopGap: CGFloat = 10
    private static let searchAllPadding: CGFloat = 20

    /// `focusesOnArrival` false keeps the keyboard down: snapshots never show it.
    public init(
        model: SearchModel,
        thumbnails: any ThumbnailProviding,
        focusesOnArrival: Bool = true,
        onOpen: @escaping (ScanID) -> Void
    ) {
        self.model = model
        self.thumbnails = thumbnails
        self.focusesOnArrival = focusesOnArrival
        self.onOpen = onOpen
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Self.fieldGap) {
                field
                GlassCircleButton(
                    systemImage: "xmark",
                    font: Tokens.Typography.headline,
                    label: Text("Close search", bundle: #bundle),
                    identifier: AccessibilityID.Search.close,
                    diameter: Self.closeDiameter,
                    action: { dismiss() })
            }
            .padding(.horizontal, Tokens.Spacing.s4)
            SearchFilterChips(selection: $model.filter)
                .padding(.top, Self.chipsTopGap)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Color.bgGrouped)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .onAppear {
            guard !hasArrived else { return }
            hasArrived = true
            isFocused = focusesOnArrival
        }
    }

    private var field: some View {
        HStack(spacing: Tokens.Spacing.s2) {
            // At accessibility sizes the glyph would leave the query too little room (it truncated at the largest
            // text, failing the audit); the placeholder still says what the field is.
            if !typeSize.isAccessibilitySize {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .accessibilityHidden(true)
            }
            TextField(
                text: query,
                prompt: prompt.foregroundStyle(Tokens.Color.textSecondary),
                axis: .vertical
            ) {
                Text("Search all scans", bundle: #bundle)
            }
            // It grows down rather than clip at large text sizes (a one-line field failed the audit's clipped-text
            // check at the largest size), up to three lines.
            .lineLimit(Self.fieldLines)
            .font(Tokens.Typography.body)
            .foregroundStyle(Tokens.Color.textPrimary)
            .focused($isFocused)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .accessibilityIdentifier(AccessibilityID.Search.field)
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Tokens.Color.textTertiary)
                        .frame(minWidth: Self.clearQuerySize, minHeight: Self.clearQuerySize)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear search", bundle: #bundle))
                .accessibilityIdentifier(AccessibilityID.Search.clearQuery)
            }
        }
        .font(Tokens.Typography.body)
        .padding(.leading, Self.fieldLeading)
        .padding(.trailing, Self.fieldTrailing)
        .frame(minHeight: Self.fieldMinHeight)
        .background(Tokens.Color.bgSurface, in: .capsule)
    }

    /// "Search all scans" (Search.dc.html line 25); at accessibility sizes just "Search", as Home's field says: the
    /// growing field shows its placeholder on one line, and the full one was cut to "Search all…".
    private var prompt: Text {
        typeSize.isAccessibilitySize ? Text("Search", bundle: #bundle) : Text("Search all scans", bundle: #bundle)
    }

    /// The field's text, through the model, which takes a Return typed at the end as the keyboard's Search.
    private var query: Binding<String> {
        Binding(
            get: { model.query },
            set: { text in
                if model.edit(text) { isFocused = false }
            })
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .firstUse:
            // 08-01: only the filters.
            Spacer(minLength: 0)
        case .beforeTyping(let viewed, let searches):
            ScrollView {
                SearchBeforeTyping(
                    viewed: viewed,
                    searches: searches,
                    thumbnails: thumbnails,
                    onOpen: onOpen,
                    onSearch: { model.query = $0 },
                    onClear: model.clearSearches
                )
                .padding(.horizontal, Tokens.Spacing.s4)
                .padding(.bottom, Tokens.Spacing.s4)
            }
            .scrollDismissesKeyboard(.immediately)
        case .results:
            ScrollView {
                results
                    .padding(.horizontal, Tokens.Spacing.s4)
                    .padding(.bottom, Tokens.Spacing.s4)
            }
            .scrollDismissesKeyboard(.immediately)
        case .nothingHere(let title, let body):
            nothing(title: title, body: body, searchAll: true)
        case .nothingAnywhere(let title, let body):
            nothing(title: title, body: body, searchAll: false)
        }
    }

    /// 08-03, 08-04: the count, then one card of rows.
    private var results: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.header)
                .font(Tokens.Typography.subheadline)
                .foregroundStyle(Tokens.Color.textSecondary)
                .padding(.top, Self.countTopGap)
                .padding(.bottom, Self.countBottomGap)
            LazyVStack(spacing: 0) {
                ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                    SearchResultRow(
                        result: result,
                        showsSeparator: index > 0,
                        thumbnails: thumbnails,
                        onOpen: { open(result.id) })
                }
            }
            .background(Tokens.Color.bgSurface, in: .rect(cornerRadius: Tokens.Radius.surface))
        }
    }

    /// 08-05, 08-06: the magnifier, what was missed and, with a filter, Search all scans; centred in what is left.
    private func nothing(title: String, body: String, searchAll: Bool) -> some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Self.emptyGap) {
                    Image(systemName: "magnifyingglass")
                        // 08-05: the magnifier is about a large title's size, in a regular stroke.
                        .font(Tokens.Typography.largeTitle.weight(.regular))
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(Tokens.Typography.headline)
                        .foregroundStyle(Tokens.Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(body)
                        .font(Tokens.Typography.subheadline)
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .frame(maxWidth: Self.emptyBodyMaxWidth)
                    if searchAll {
                        Button {
                            model.searchAll()
                        } label: {
                            Text("Search all scans", bundle: #bundle)
                                .font(Tokens.Typography.headline)
                                .foregroundStyle(Tokens.Color.textPrimary)
                                .padding(.horizontal, Self.searchAllPadding)
                                .frame(minHeight: Tokens.Spacing.tapMin)
                                .background(Tokens.Color.bgSurface, in: .capsule)
                                .contentShape(.capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(AccessibilityID.Search.searchAll)
                        .padding(.top, Self.searchAllTopGap)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Spacing.s6)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    /// Opening a result keeps the search (M5); the viewer records the scan as viewed.
    private func open(_ id: ScanID) {
        model.opened(id)
        onOpen(id)
    }
}
