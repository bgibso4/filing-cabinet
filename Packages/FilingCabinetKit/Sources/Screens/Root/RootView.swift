import Core
import ScreenModels
import SwiftUI

/// The app's one navigation stack: Home at the root, collections, views and scans pushed on top.
public struct RootView: View {
    private let dependencies: RootDependencies
    @State private var path: [AppRoute] = []

    public init(dependencies: RootDependencies) {
        self.dependencies = dependencies
    }

    public var body: some View {
        NavigationStack(path: $path) {
            HomeView(model: dependencies.home, onScan: {}, onOpen: { path.append($0) })
                // Home draws its own large title (Home.dc.html); pushed screens bring their own headers.
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AppRoute.self, destination: destination)
        }
    }

    /// Placeholders until the grid (Task 16) and the viewer (Task 17) fill these in.
    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .collection(let collection):
            placeholder(CollectionText.name(collection))
        case .recent:
            placeholder(CollectionText.recent)
        case .all:
            placeholder(CollectionText.allScans)
        case .scan:
            Tokens.Color.bgGrouped.ignoresSafeArea()
        }
    }

    private func placeholder(_ name: String) -> some View {
        Text(name)
            .accessibilityIdentifier(AccessibilityID.Grid.header)
    }
}
