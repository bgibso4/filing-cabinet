import Foundation

/// Why the library could not save. ENOSPC and `CocoaError.fileWriteOutOfSpace` are `.diskFull`;
/// everything else is `.writeFailed`.
package enum LibraryError: Error, Equatable {
    case diskFull
    case writeFailed

    /// Classifies a file-system error.
    init(_ error: any Error) {
        if let posix = error as? POSIXError, posix.code == .ENOSPC {
            self = .diskFull
        } else if let cocoa = error as? CocoaError, cocoa.code == .fileWriteOutOfSpace {
            self = .diskFull
        } else if let underlying = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError,
            underlying.domain == NSPOSIXErrorDomain, underlying.code == Int(ENOSPC)
        {
            self = .diskFull
        } else {
            self = .writeFailed
        }
    }
}
