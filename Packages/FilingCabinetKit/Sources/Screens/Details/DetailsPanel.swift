import Core
import ScreenModels
import SwiftUI

/// Details floating over the viewer (B10): our own panel rather than a system sheet, so one progress value moves it,
/// the page and the chrome together (#61). The same look as the sheet it replaces: the surface colour, 34 pt corners,
/// 8 pt from the screen's sides and bottom, and the sheet's own grabber. It doesn't dim the viewer, rides above the
/// keyboard while renaming, and follows a drag on its grabber, or on its body once the body is at its top.
public struct DetailsPanel: View {
    // ScanDetails.dc.html line 34: 8 pt from the screen's sides and bottom, with 34 pt corners.
    static let inset: CGFloat = 8
    private static let cornerRadius: CGFloat = 34

    private let model: DetailsModel
    /// 0 below the screen's bottom edge, 1 fully up.
    private let progress: CGFloat
    /// The panel's laid-out height, which the viewer fits the page above and a drag's travel comes from.
    @Binding private var height: CGFloat
    private let onDrag: (DetailsDrag) -> Void
    private let onClose: () -> Void

    public init(
        model: DetailsModel,
        progress: CGFloat,
        height: Binding<CGFloat>,
        onDrag: @escaping (DetailsDrag) -> Void = { _ in },
        onClose: @escaping () -> Void = {}
    ) {
        self.model = model
        self.progress = progress
        _height = height
        self.onDrag = onDrag
        self.onClose = onClose
    }

    public var body: some View {
        DetailsSheet(model: model, onDrag: onDrag)
            .background(Tokens.Color.bgSurface)
            .clipShape(.rect(cornerRadius: Self.cornerRadius, style: .continuous))
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { height = $0 }
            .contentShape(.rect(cornerRadius: Self.cornerRadius, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.Details.sheet)
            .accessibilityAction(.escape, onClose)
            .padding([.horizontal, .bottom], Self.inset)
            // The panel's own laid-out size, so even its first frame starts fully below the screen.
            .visualEffect { [progress] content, proxy in
                content.offset(y: DetailsMotion.panelOffset(progress: progress, travel: proxy.size.height))
            }
            // Down to the screen's bottom edge, but above the keyboard.
            .ignoresSafeArea(.container, edges: .bottom)
    }
}
