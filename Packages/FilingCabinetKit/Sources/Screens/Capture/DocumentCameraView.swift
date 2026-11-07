import CoreGraphics
import SwiftUI
import VisionKit

/// VisionKit's document camera. Reports the scanned pages, a cancel or a failure.
struct DocumentCameraView: UIViewControllerRepresentable {
    let onFinish: ([CGImage]) -> Void
    let onCancel: () -> Void
    let onFail: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: DocumentCameraView

        init(parent: DocumentCameraView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan
        ) {
            let pages = (0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).cgImage }
            parent.onFinish(pages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController, didFailWithError error: any Error
        ) {
            let error = error as NSError
            ScreensLog.logger.error(
                "Document camera failed: \(error.domain, privacy: .public) \(error.code, privacy: .public)")
            parent.onFail()
        }
    }
}
