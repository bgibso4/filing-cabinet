import Core
import ScreenModels
import SwiftUI

/// The app's one navigation stack: Home at the root, collections, views and scans pushed on top.
public struct RootView: View {
    private let dependencies: RootDependencies
    // periphery:ignore - only bound so far: Home's rows push onto it from Task 12.
    @State private var path: [AppRoute] = []

    public init(dependencies: RootDependencies) {
        self.dependencies = dependencies
    }

    public var body: some View {
        NavigationStack(path: $path) {
            HomeView(model: dependencies.home, onScan: {})
                // Home draws its own large title (Home.dc.html); pushed screens bring their own headers.
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AppRoute.self, destination: destination)
        }
    }

    /// Nothing pushes yet: Home's rows (Task 12), the grid (Task 16) and the viewer (Task 17) fill these in.
    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .collection, .recent, .all, .scan:
            Tokens.Color.bgGrouped.ignoresSafeArea()
        }
    }
}
