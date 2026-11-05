import Core
import CoreGraphics
import SwiftUI

/// Stands in for VisionKit's camera in UI tests (M16): Finish returns the injected pages, Cancel cancels.
struct FakeCameraView: View {
    let pages: @Sendable () -> [CGImage]
    let onFinish: ([CGImage]) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Spacing.s6) {
            Button {
                onFinish(pages())
            } label: {
                Text("Finish", bundle: #bundle)
            }
            .accessibilityIdentifier(AccessibilityID.Camera.fakeFinish)
            Button {
                onCancel()
            } label: {
                Text("Cancel", bundle: #bundle)
            }
            .accessibilityIdentifier(AccessibilityID.Camera.fakeCancel)
        }
        .font(Tokens.Typography.headline)
        .foregroundStyle(Tokens.Color.tint)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Color.bgGrouped)
    }
}
