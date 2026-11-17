import SwiftUI
import UIKit

/// The shield: a window of the app's scene above the app's own window, so the lock cover hides everything that window
/// shows, Search's cover and the sheets it presents (Share, Mail) included, and the app switcher's snapshot. The system
/// Face ID prompt is drawn outside the app, above it. `isUp` comes from `LibraryLock.shieldIsUp`.
///
/// With the lock on (`coversInBackground`) it also goes up by itself as the scene enters the background, inside that
/// notification, so the cover is in the window before iOS takes the switcher's snapshot whenever the root's next
/// render happens; `isUp` then agrees, and takes it down on the way back.
///
/// It sits as an empty background in the app's window, to find the scene. The window is made the first time the shield
/// goes up, so with the lock off the app has no extra window. While it is up, the app's window is out of the
/// accessibility tree and its keyboard is put away, so neither VoiceOver nor typing reaches the library; when it goes,
/// VoiceOver is sent back to the app's window.
struct LockShield: UIViewRepresentable {
    let isUp: Bool
    let coversInBackground: Bool
    let showsUnlock: Bool
    /// Settings › Appearance, as the root applies it; nil follows the phone.
    let colorScheme: ColorScheme?
    let onUnlock: () -> Void

    func makeUIView(context: Context) -> Anchor {
        let anchor = Anchor()
        anchor.isUserInteractionEnabled = false
        return anchor
    }

    func updateUIView(_ anchor: Anchor, context: Context) {
        anchor.update(
            cover: LockCover(showsUnlock: showsUnlock, onUnlock: onUnlock),
            isUp: isUp,
            coversInBackground: coversInBackground,
            style: colorScheme.map(UIUserInterfaceStyle.init) ?? .unspecified)
    }

    static func dismantleUIView(_ anchor: Anchor, coordinator: ()) {
        anchor.takeDown()
    }

    /// Holds the shield's window and keeps it in step with the root.
    final class Anchor: UIView {
        private var shield: UIWindow?
        private var host: UIHostingController<LockCover>?
        /// The app's window the shield covers, kept to give back its accessibility when the shield goes.
        private weak var covered: UIWindow?
        private var cover = LockCover(showsUnlock: false, onUnlock: {})
        private var isUp = false
        private var coversInBackground = false
        private var style = UIUserInterfaceStyle.unspecified

        override init(frame: CGRect) {
            super.init(frame: frame)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(sceneEnteredBackground),
                name: UIScene.didEnterBackgroundNotification,
                object: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not used")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        func update(cover: LockCover, isUp: Bool, coversInBackground: Bool, style: UIUserInterfaceStyle) {
            self.cover = cover
            self.isUp = isUp
            self.coversInBackground = coversInBackground
            self.style = style
            apply()
        }

        @objc private func sceneEnteredBackground(_ notification: Notification) {
            guard coversInBackground, let scene = window?.windowScene, notification.object as? UIScene === scene
            else { return }
            isUp = true
            apply()
        }

        /// The root has gone (a UI test's relaunch builds it again): the shield goes with it.
        func takeDown() {
            isUp = false
            show(false)
            shield = nil
            host = nil
        }

        private func apply() {
            guard isUp || shield != nil, let appWindow = window, let scene = appWindow.windowScene else { return }
            covered = appWindow
            let shield = shield ?? makeShield(in: scene)
            host?.rootView = cover
            shield.overrideUserInterfaceStyle = style
            show(isUp)
        }

        private func makeShield(in scene: UIWindowScene) -> UIWindow {
            let host = UIHostingController(rootView: cover)
            let shield = UIWindow(windowScene: scene)
            // Above the app's window and any alert it shows; the keyboard's own window is put away instead.
            shield.windowLevel = .alert + 1
            shield.rootViewController = host
            shield.isHidden = true
            self.host = host
            self.shield = shield
            return shield
        }

        /// Only on a change, so VoiceOver isn't sent to the cover again on every update.
        private func show(_ isShown: Bool) {
            guard let shield, shield.isHidden == isShown else { return }
            shield.isHidden = !isShown
            covered?.accessibilityElementsHidden = isShown
            if isShown {
                covered?.endEditing(true)
                UIAccessibility.post(notification: .screenChanged, argument: shield)
            } else {
                // VoiceOver's focus was on the cover, which has gone: it moves to what the app shows now.
                UIAccessibility.post(notification: .screenChanged, argument: covered)
            }
        }
    }
}
