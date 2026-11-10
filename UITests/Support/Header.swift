import Core
import XCTest

/// The size a header's title shows at.
enum HeaderSize {
    case large, small
}

// The bar's top row, where the back button and the small title sit: 44 pt (the back button's height, measured in the
// accessibility tree on FC iPhone 17). The large title sits below it.
private let barRowHeight: CGFloat = 44

extension XCUIApplication {
    /// A screen's header: the system bar, with its own title (plan 3, E9). The bar takes the title as its identifier,
    /// so a screen is found by what its title says.
    func header(_ title: String) -> XCUIElement {
        navigationBars[title]
    }

    /// A collection's grid header.
    func header(_ collection: BuiltInCollection) -> XCUIElement {
        header(collection.rawValue.capitalized)
    }

    /// The title text in `title`'s header: one element, small in the bar's row or large under it.
    func headerTitle(_ title: String) -> XCUIElement {
        header(title).staticTexts[title]
    }

    func headerTitle(_ collection: BuiltInCollection) -> XCUIElement {
        headerTitle(collection.rawValue.capitalized)
    }

    /// True once `title`'s header shows its title at `size`, within `timeout` seconds.
    func header(_ title: String, shows size: HeaderSize, within timeout: TimeInterval) -> Bool {
        header(title).satisfies(within: timeout) { bar in
            let text = bar.staticTexts[title]
            guard text.exists else { return false }
            let isLarge = text.frame.minY >= bar.frame.minY + barRowHeight
            return isLarge == (size == .large)
        }
    }

    func header(_ collection: BuiltInCollection, shows size: HeaderSize, within timeout: TimeInterval) -> Bool {
        header(collection.rawValue.capitalized, shows: size, within: timeout)
    }
}
