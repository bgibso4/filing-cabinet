import CoreTransferable
import Foundation
import UniformTypeIdentifiers

// periphery:ignore - Task 11 (Plan 4) shares it; remove this when it lands
/// A scan shared as a PDF. The file is made only when the share sheet or file exporter asks for it.
package struct ScanPDF: Transferable {
    package let scan: ScanSummary
    package let export: ScanExport
    /// The PDF's name without its extension, from `ScanExport.fileName`.
    package let suggestedFileName: String

    package init(scan: ScanSummary, export: ScanExport, suggestedFileName: String) {
        self.scan = scan
        self.export = export
        self.suggestedFileName = suggestedFileName
    }

    package static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf, shouldAllowToOpenInPlace: false) { pdf in
            SentTransferredFile(try await pdf.export.pdf(for: pdf.scan, named: pdf.suggestedFileName))
        }
        .suggestedFileName { $0.suggestedFileName + ".pdf" }
    }
}
