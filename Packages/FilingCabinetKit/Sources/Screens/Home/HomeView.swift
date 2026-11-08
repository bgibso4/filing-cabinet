import Core
import Library
import ScreenModels
import SwiftUI

/// Home: the title with the Settings gear, the five collections with their counts, the Recent, All Scans and Trash
/// views, and the Scan button. Before the first scan it shows the collections' descriptions instead.
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
    // 02-04 (Home.dc.html's after-a-cleanup state): the gear is a 44 pt glass circle at the title's right.
    private static let gearDiameter: CGFloat = 44
    // Home.dc.html line 27: the cleanup banner is a 44 pt link tucked 8 pt up under the title and 6 pt over what
    // follows.
    private static let bannerMinHeight: CGFloat = 44
    private static let bannerTopOverlap: CGFloat = -8
    private static let bannerBottomOverlap: CGFloat = -6

    /// `canScan` false keeps the Scan button disabled (until launch cleanup has finished).
    public init(
        model: HomeModel, canScan: Bool, onScan: @escaping () -> Void, onOpen: @escaping (AppRoute) -> Void
    ) {
        self.model = model
        self.canScan = canScan
        self.onScan = onScan
        self.onOpen = onOpen
    }

    public var body: some View {
        ScanBarLayout(canScan: canScan, scanIdentifier: AccessibilityID.Home.scan, onScan: onScan) {
            scrolling
        }
    }

    private var scrolling: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Tokens.Spacing.s3) {
                    Text("Filing Cabinet", bundle: #bundle)
                        .font(Tokens.Typography.largeTitle)
                        .tracking(Tokens.Typography.largeTitleTracking)
                        .foregroundStyle(Tokens.Color.textPrimary)
                        .frame(minHeight: Self.headerMinHeight)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    GlassCircleButton(
                        systemImage: "gearshape",
                        font: Tokens.Typography.title2.weight(.regular),
                        label: Text("Settings", bundle: #bundle),
                        identifier: AccessibilityID.Home.settings,
                        diameter: Self.gearDiameter
                    ) {
                        onOpen(.settings)
                    }
                }
                if let banner = model.banner {
                    cleanupBanner(banner)
                }
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

    /// 02-04: "4 scans moved to Trash · View" under the title. View opens Trash and clears it.
    private func cleanupBanner(_ text: String) -> some View {
        Button {
            model.clearBanner()
            onOpen(.trash)
        } label: {
            let view = Text("View", bundle: #bundle).fontWeight(.semibold).foregroundStyle(Tokens.Color.textPrimary)
            Text("\(text) · \(view)", bundle: #bundle)
                .font(Tokens.Typography.subheadline)
                .foregroundStyle(Tokens.Color.textSecondary)
                .frame(minHeight: Self.bannerMinHeight, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Home.cleanupBanner)
        .padding(.top, Self.bannerTopOverlap)
        .padding(.bottom, Self.bannerBottomOverlap)
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
        case .trash: .trash
        }
    }
}

/// An empty library for previews: Screens does not depend on TestSupport, and the fakes there need a test target.
@MainActor
private final class PreviewLibrary: ScanLibrary {
    let scans: [ScanSummary] = []
    let lifespans = CollectionLifespans.defaults
    func save(_ draft: ScanDraft) async throws(LibraryError) {}
    func updateSearchText(_ text: String, for id: ScanID) {}
    func rename(_ id: ScanID, to title: String) throws(LibraryError) {}
    func move(_ id: ScanID, to collection: BuiltInCollection) throws(LibraryError) {}
    func setExpiry(_ override: ExpiryOverride?, for id: ScanID) throws(LibraryError) {}
    func moveToTrash(_ ids: [ScanID]) throws(LibraryError) {}
    func restore(_ ids: [ScanID]) throws(LibraryError) {}
    func deleteNow(_ ids: [ScanID]) async throws(LibraryError) {}
    func emptyTrash() async throws(LibraryError) -> Int { 0 }
    func setLifespan(_ lifespan: Lifespan, for collection: BuiltInCollection) throws(LibraryError) {}
    func scansExpiring(ifLifespan lifespan: Lifespan, for collection: BuiltInCollection) -> Int { 0 }
}

@MainActor
private func previewModel() -> HomeModel {
    HomeModel(library: PreviewLibrary(), today: Today(clock: .system), calendar: AppClock.system.calendar)
}

#Preview("Light") {
    HomeView(model: previewModel(), canScan: true, onScan: {}, onOpen: { _ in })
}

#Preview("Dark") {
    HomeView(model: previewModel(), canScan: true, onScan: {}, onOpen: { _ in }).preferredColorScheme(.dark)
}

#Preview("Accessibility 5") {
    HomeView(model: previewModel(), canScan: true, onScan: {}, onOpen: { _ in }).dynamicTypeSize(.accessibility5)
}
