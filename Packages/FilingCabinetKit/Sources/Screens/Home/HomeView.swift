import Core
import Library
import ScreenModels
import SwiftUI

/// Home: the five collections with their counts, the Recent and All Scans views, and the Scan button. Before the
/// first scan it shows the collections' descriptions instead.
public struct HomeView: View {
    private let model: HomeModel
    private let canScan: Bool
    private let onScan: () -> Void
    private let onOpen: (AppRoute) -> Void

    // Home.dc.html: the large-title and section-header rows are at least this tall.
    private static let headerMinHeight: CGFloat = 44
    // Home.dc.html line 366: gap above "Collections" is 18 pt on first launch and 6 pt once there are scans.
    private static let firstLaunchCollectionsTopGap: CGFloat = 18
    private static let collectionsTopGap: CGFloat = 6
    // Home.dc.html line 175: the views card sits 16 pt below the collections.
    private static let viewsTopGap: CGFloat = 16
    // Home.dc.html: the fade behind the pill is solid from 38% of its height.
    private static let fadeSolidLocation: Double = 0.38

    /// `canScan` false keeps the Scan button disabled (until launch cleanup has finished).
    public init(
        model: HomeModel, canScan: Bool = true, onScan: @escaping () -> Void, onOpen: @escaping (AppRoute) -> Void
    ) {
        self.model = model
        self.canScan = canScan
        self.onScan = onScan
        self.onOpen = onOpen
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    public var body: some View {
        if typeSize.isAccessibilitySize {
            // At accessibility sizes the list is taller than the screen, so a row would rest half under the Scan
            // button's fade. The list ends where the button's area begins instead.
            VStack(spacing: 0) {
                scrolling
                scanBar(fades: false)
            }
            .background(Tokens.Color.bgGrouped)
        } else {
            scrolling
                .background(Tokens.Color.bgGrouped)
                .safeAreaInset(edge: .bottom, spacing: 0) { scanBar(fades: true) }
        }
    }

    private var scrolling: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Filing Cabinet", bundle: #bundle)
                    .font(Tokens.Typography.largeTitle)
                    .tracking(Tokens.Typography.largeTitleTracking)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .frame(minHeight: Self.headerMinHeight)
                    .accessibilityAddTraits(.isHeader)
                Text("Collections", bundle: #bundle)
                    .font(Tokens.Typography.title2)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .frame(minHeight: Self.headerMinHeight)
                    .padding(.top, model.isEmpty ? Self.firstLaunchCollectionsTopGap : Self.collectionsTopGap)
                    .accessibilityAddTraits(.isHeader)
                collections
                views
            }
            .padding(.horizontal, Tokens.Spacing.s4)
        }
    }

    private var collections: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                HomeRowView(row: row, showsSeparator: index > 0) { onOpen(.collection(row.collection)) }
            }
        }
        .background(Tokens.Color.bgSurface, in: .rect(cornerRadius: Tokens.Radius.surface))
    }

    @ViewBuilder
    private var views: some View {
        let rows = model.viewRows
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HomeViewRowView(row: row, showsSeparator: index > 0) { onOpen(route(for: row)) }
                }
            }
            .background(Tokens.Color.bgSurface, in: .rect(cornerRadius: Tokens.Radius.surface))
            .padding(.top, Self.viewsTopGap)
        }
    }

    private func route(for row: HomeViewRow) -> AppRoute {
        switch row.kind {
        case .recent: .recent
        case .all: .all
        }
    }

    /// The Scan button at the bottom centre. At default sizes it floats over the content on a fade of the screen
    /// background (as a safe-area inset it pushes the scroll content up by its real size); at accessibility sizes
    /// it sits on the plain background below the list.
    private func scanBar(fades: Bool) -> some View {
        ScanButton(action: onScan)
            .disabled(!canScan)
            .padding(.top, Tokens.Spacing.s4)
            .frame(maxWidth: .infinity)
            .background {
                if fades {
                    LinearGradient(
                        stops: [
                            .init(color: Tokens.Color.bgGrouped.opacity(0), location: 0),
                            .init(color: Tokens.Color.bgGrouped, location: Self.fadeSolidLocation),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)
                }
            }
    }
}

/// An empty library for previews: Screens does not depend on TestSupport, and the fakes there need a test target.
@MainActor
private final class PreviewLibrary: ScanLibrary {
    let scans: [ScanSummary] = []
    func save(_ draft: ScanDraft) async throws(LibraryError) {}
    func updateSearchText(_ text: String, for id: ScanID) {}
}

@MainActor
private func previewModel() -> HomeModel {
    HomeModel(library: PreviewLibrary(), today: Today(clock: .system), calendar: AppClock.system.calendar)
}

#Preview("Light") {
    HomeView(model: previewModel(), onScan: {}, onOpen: { _ in })
}

#Preview("Dark") {
    HomeView(model: previewModel(), onScan: {}, onOpen: { _ in }).preferredColorScheme(.dark)
}

#Preview("Accessibility 5") {
    HomeView(model: previewModel(), onScan: {}, onOpen: { _ in }).dynamicTypeSize(.accessibility5)
}
