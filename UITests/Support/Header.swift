import Core
import ScreenModels
import XCTest

/// The size a header's title shows at.
enum HeaderSize {
    case large, small
}

// The bar's top row, where the back button and the small title sit: 44 pt (the back button's height, measured in the
// accessibility tree on FC iPhone 17). The large title sits below it.
private let barRowHeight: CGFloat = 44

/// The system's gap from the back button to the large title's text frame: 17.33 pt (plan 3, E9, FC iPhone 17).
let largeTitleGap: CGFloat = 17.33
/// How far a measured gap may be from `largeTitleGap` (the frames round to a third of a point; #75's was 24 pt off).
let largeTitleGapTolerance: CGFloat = 1

extension XCUIApplication {
    /// A screen's header: the system bar, with its own title (plan 3, E9). The bar takes the title as its identifier,
    /// so a screen is found by what its title says.
    func header(_ title: String) -> XCUIElement {
        navigationBars[title]
    }

    /// A collection's grid header.
    func header(_ collection: BuiltInCollection) -> XCUIElement {
        header(CollectionText.name(collection))
    }

    /// The title text in `title`'s header: one element, small in the bar's row or large under it.
    func headerTitle(_ title: String) -> XCUIElement {
        header(title).staticTexts[title]
    }

    func headerTitle(_ collection: BuiltInCollection) -> XCUIElement {
        headerTitle(CollectionText.name(collection))
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

    /// The gap from the back button down to `title`'s large title, to compare with `largeTitleGap`.
    func largeTitleGap(_ title: String) -> CGFloat {
        headerTitle(title).frame.minY - buttons[AccessibilityID.Grid.back].frame.maxY
    }

    func header(_ collection: BuiltInCollection, shows size: HeaderSize, within timeout: TimeInterval) -> Bool {
        header(CollectionText.name(collection), shows: size, within: timeout)
    }
}
