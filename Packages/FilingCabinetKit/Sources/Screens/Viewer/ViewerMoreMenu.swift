import Core
import ScreenModels
import SwiftUI
import UIKit

/// The viewer's "•••" at the top's trailing edge (ScanView.dc.html line 225) and its menu (06-03, M11): Save to Photos,
/// Save to Files and Copy Text, in that order, each with its symbol. Copy Text is greyed out when the scan has no text.
/// A `MenuButton`, as the codebase's other menus: SwiftUI's `Menu` adds a second, unidentified button inside its own.
struct ViewerMoreMenu: View {
    let model: ViewerModel
    /// Save to Files: the viewer puts up the system's file exporter.
    let onSaveToFiles: () -> Void
    /// A save or copy succeeded, with what VoiceOver hears.
    let onExported: (String) -> Void

    var body: some View {
        Image(systemName: "ellipsis")
            .frame(minWidth: Tokens.Spacing.tapMin, minHeight: Tokens.Spacing.tapMin)
            .accessibilityHidden(true)
            .overlay {
                MenuButton(
                    label: String(localized: "More", bundle: #bundle),
                    value: "",
                    identifier: AccessibilityID.Viewer.more,
                    menu: menu)
            }
    }

    private func menu() -> UIMenu {
        let copyText = action(String(localized: "Copy Text", bundle: #bundle), "doc.on.doc", copy)
        if !model.canCopyText { copyText.attributes = .disabled }
        return UIMenu(children: [
            action(String(localized: "Save to Photos", bundle: #bundle), "photo", saveToPhotos),
            action(String(localized: "Save to Files", bundle: #bundle), "folder", onSaveToFiles),
            copyText,
        ])
    }

    private func saveToPhotos() {
        Task {
            if await model.saveToPhotos() { onExported(ExportText.savedToPhotos) }
        }
    }

    private func copy() {
        if model.copyText(to: { UIPasteboard.general.string = $0 }) { onExported(ExportText.copied) }
    }

    private func action(_ title: String, _ systemImage: String, _ perform: @escaping () -> Void) -> UIAction {
        UIAction(title: title, image: UIImage(systemName: systemImage)) { _ in perform() }
    }
}
