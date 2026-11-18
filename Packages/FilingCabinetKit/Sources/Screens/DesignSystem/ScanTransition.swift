import Core
import SwiftUI

extension EnvironmentValues {
    /// Where a scan's thumbnail and its viewer match up, set by the navigation stack that pushes the viewer (#98). Nil
    /// outside one (a snapshot of a single screen): a thumbnail then marks nothing.
    @Entry var scanTransition: Namespace.ID?
}

extension View {
    /// Marks a scan's thumbnail as where its viewer zooms from, and back into on a swipe down, like Photos (#98). Every
    /// thumbnail that opens a scan is clipped to the nested radius, so the zoom keeps it.
    func scanTransitionSource(_ id: ScanID) -> some View {
        modifier(ScanTransitionSource(id: id))
    }

    /// The viewer, zooming out of its scan's thumbnail and back into it (#98). A scan opened from outside the app has no
    /// thumbnail on screen: the system zooms from the middle.
    func scanTransition(_ id: ScanID) -> some View {
        modifier(ScanTransitionDestination(id: id))
    }

    /// Gives a navigation stack, set on it, the namespace its thumbnails and viewers match up in (#98).
    func scanTransitionScope() -> some View {
        modifier(ScanTransitionScope())
    }
}

private struct ScanTransitionScope: ViewModifier {
    @Namespace private var namespace

    func body(content: Content) -> some View {
        content.environment(\.scanTransition, namespace)
    }
}

private struct ScanTransitionDestination: ViewModifier {
    let id: ScanID
    @Environment(\.scanTransition) private var namespace

    func body(content: Content) -> some View {
        if let namespace {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

private struct ScanTransitionSource: ViewModifier {
    let id: ScanID
    @Environment(\.scanTransition) private var namespace

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace) { source in
                source.clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.nested))
            }
        } else {
            content
        }
    }
}
