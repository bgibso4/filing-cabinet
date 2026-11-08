import Core
import ScreenModels
import SwiftUI
import UIKit

/// The Collection row and its menu (03-06, 07-04): each collection with its lifespan and its badge. Review and Details
/// share it.
struct CollectionMenu: View {
    let label: String
    let value: String
    /// Nil until one is chosen (Review's prompt).
    let collection: BuiltInCollection?
    let options: [CollectionOption]
    let identifier: String
    let choose: (BuiltInCollection) -> Void

    // Review.dc.html line 292, ScanDetails.dc.html line 75: once chosen, the collection's badge is 31 pt with a 17 pt
    // symbol.
    private static let badgeDiameter: CGFloat = 31
    private static let badgeSymbol: CGFloat = 17
    // Review.dc.html line 320: in the menu the badge is 24 pt with a 13 pt symbol.
    private static let menuBadgeDiameter: CGFloat = 24
    private static let menuBadgeSymbol: CGFloat = 13

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ReviewRow(label: label, value: value, isPrompt: collection == nil) {
            if let collection {
                CollectionBadge(collection: collection, diameter: Self.badgeDiameter, symbolSize: Self.badgeSymbol)
            } else {
                DashedFolder()
            }
        }
        .accessibilityHidden(true)
        .overlay {
            MenuButton(label: label, value: value, identifier: identifier, menu: menu)
        }
    }

    private func menu() -> UIMenu {
        UIMenu(
            children: options.map { option in
                let action = UIAction(
                    title: option.name, subtitle: option.lifespan, image: badge(option.collection)
                ) { _ in
                    choose(option.collection)
                }
                action.state = collection == option.collection ? .on : .off
                return action
            })
    }

    /// The collection's badge as an image, in its own colours (the system draws menu images on the leading side).
    private func badge(_ collection: BuiltInCollection) -> UIImage? {
        let renderer = ImageRenderer(
            content: CollectionBadge(
                collection: collection, diameter: Self.menuBadgeDiameter, symbolSize: Self.menuBadgeSymbol))
        renderer.scale = displayScale
        return renderer.uiImage?.withRenderingMode(.alwaysOriginal)
    }
}
