import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A scan shared as a PDF. The file is made only when the share sheet or file exporter asks for it.
package struct ScanPDF: Transferable {
    private let scan: ScanSummary
    private let exported: ExportedFiles
    /// The PDF's name without its extension, from `ScanExport.fileName`.
    package let suggestedFileName: String
    /// Told once the file is made: the share sheet gives no other sign that the scan left the app.
    private let made: @Sendable () -> Void

    package init(
        scan: ScanSummary,
        exported: ExportedFiles,
        suggestedFileName: String,
        made: @escaping @Sendable () -> Void = {}
    ) {
        self.scan = scan
        self.exported = exported
        self.suggestedFileName = suggestedFileName
        self.made = made
    }

    /// Makes the PDF in the export folder, kept by `exported` for removal when the export ends.
    package func file() async throws(LibraryError) -> URL {
        let url = try await exported.pdf(for: scan, named: suggestedFileName)
        made()
        return url
    }

    package static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf, shouldAllowToOpenInPlace: false) { pdf in
            SentTransferredFile(try await pdf.file())
        }
        .suggestedFileName { $0.suggestedFileName + ".pdf" }
    }
}
