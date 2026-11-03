import Foundation
import Library
import TestSupport
import Testing

@Test func firstWriteFailsThenSucceeds() throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: "FailOnceFileSystemTests-\(UUID().uuidString)")
    let fileSystem = FailOnceFileSystem(LocalFileSystem())
    try fileSystem.createDirectory(at: folder)
    let file = folder.appending(path: "page-1.heic")

    #expect(throws: POSIXError(.ENOSPC)) {
        try fileSystem.write(Data([1]), to: file)
    }
    #expect(!fileSystem.fileExists(at: file))

    try fileSystem.write(Data([1]), to: file)
    try fileSystem.write(Data([2]), to: file)

    #expect(try Data(contentsOf: file) == Data([2]))
}
